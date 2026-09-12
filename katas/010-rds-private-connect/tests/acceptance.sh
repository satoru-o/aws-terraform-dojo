#!/usr/bin/env bash
#
# 010-rds-private-connect 受入テスト雛形（特別枠）
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. outputs.tf に、302までの値に加えて以下を出力しておくこと
#        - private_subnet2_id / rds_security_group_id / db_instance_identifier
#        - rds_endpoint / rds_port
#   3. WebサーバーにSSM Run Commandを実行できるIAMロールが付与されていること
#      （SSMエージェントの起動には数十秒〜数分かかることがある）
#
# コストに関する注意:
#   RDS・NATゲートウェイは時間課金です。確認が終わったら `terraform destroy` してください。
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
SSM_WAIT_SECONDS="${SSM_WAIT_SECONDS:-60}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== terraform output の取得 =="
WEB_IP=$(terraform -chdir="$TF_DIR" output -raw public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw instance_id 2>/dev/null || echo "")
SG_ID=$(terraform -chdir="$TF_DIR" output -raw security_group_id 2>/dev/null || echo "")
BASTION_SG_ID=$(terraform -chdir="$TF_DIR" output -raw bastion_security_group_id 2>/dev/null || echo "")
RDS_SG_ID=$(terraform -chdir="$TF_DIR" output -raw rds_security_group_id 2>/dev/null || echo "")
DB_INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw db_instance_identifier 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw rds_endpoint 2>/dev/null || echo "")
RDS_PORT=$(terraform -chdir="$TF_DIR" output -raw rds_port 2>/dev/null || echo "")

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" || -z "$BASTION_SG_ID" || -z "$RDS_SG_ID" || -z "$DB_INSTANCE_ID" || -z "$RDS_ENDPOINT" || -z "$RDS_PORT" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義を確認してください。"
  exit 1
fi
echo "Web: $INSTANCE_ID / RDS: $DB_INSTANCE_ID ($RDS_ENDPOINT:$RDS_PORT)"
echo

echo "== テスト1: Web SG・RDS SGがいずれもSG参照のみでCIDR許可を持たないか =="
# TODO: RDS_SG側はDBポート（MySQLなら3306、PostgreSQLなら5432）を選んだ場合、
#       下記のUserIdGroupPairsクエリに `FromPort==\`<自分のDBポート>\`` を足すと、
#       より厳密に「そのポートのルールが正しいか」まで確認できる。
WEB_SG_REF=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].UserIdGroupPairs[] | [?GroupId=='${BASTION_SG_ID}']" \
  --output text)
WEB_SG_CIDR=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[].IpRanges[]" \
  --output text)
RDS_SG_REF=$(aws ec2 describe-security-groups \
  --group-ids "$RDS_SG_ID" \
  --query "SecurityGroups[0].IpPermissions[].UserIdGroupPairs[] | [?GroupId=='${SG_ID}']" \
  --output text)
RDS_SG_CIDR=$(aws ec2 describe-security-groups \
  --group-ids "$RDS_SG_ID" \
  --query "SecurityGroups[0].IpPermissions[].IpRanges[]" \
  --output text)
if [[ -n "$WEB_SG_REF" && -z "$WEB_SG_CIDR" && -n "$RDS_SG_REF" && -z "$RDS_SG_CIDR" ]]; then
  pass "Web SG・RDS SGとも送信元はSG参照のみ（CIDR許可なし）"
else
  fail "Web SG参照: $([[ -n "$WEB_SG_REF" ]] && echo あり || echo なし)/CIDR: ${WEB_SG_CIDR:-なし} / RDS SG参照: $([[ -n "$RDS_SG_REF" ]] && echo あり || echo なし)/CIDR: ${RDS_SG_CIDR:-なし}"
fi
echo

echo "== テスト2: 外部からWebサーバーへのHTTP直接アクセスが失敗するか =="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CONNECT_TIMEOUT" "http://${WEB_IP}/" || echo "000")
if [[ ! "$HTTP_CODE" =~ ^[23] ]]; then
  pass "外部からの直接アクセスは失敗（ステータス: ${HTTP_CODE}）"
else
  fail "外部から直接アクセスできてしまいました（ステータス: ${HTTP_CODE}）"
fi
echo

echo "== テスト3: RDSがパブリックアクセス不可で、2つの異なるAZにまたがっているか =="
RDS_PUBLIC=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].PubliclyAccessible' --output text)
AZ_COUNT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[].SubnetAvailabilityZone.Name' --output text \
  | tr '\t' '\n' | sort -u | wc -l | tr -d '[:space:]')
if [[ "$RDS_PUBLIC" == "False" && "$AZ_COUNT" -ge 2 ]]; then
  pass "RDSはパブリックアクセス不可、DBサブネットグループは${AZ_COUNT}個のAZにまたがる"
else
  fail "PubliclyAccessible: $RDS_PUBLIC / AZ数: $AZ_COUNT"
fi
echo

echo "== テスト4: SSM経由でWebサーバーからRDSへのTCP到達性を確認 =="
CHECK_CMD="timeout 3 bash -c \"echo > /dev/tcp/${RDS_ENDPOINT}/${RDS_PORT}\" && echo DB_REACHABLE_OK || echo DB_REACHABLE_FAIL"
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$CHECK_CMD\"]" \
  --query 'Command.CommandId' --output text 2>/dev/null || echo "")

if [[ -z "$COMMAND_ID" ]]; then
  fail "aws ssm send-command が失敗しました（IAMロール・SSMエージェントの起動状況を確認してください）"
else
  echo "  SSM CommandId: $COMMAND_ID（完了を待機中、最大 ${SSM_WAIT_SECONDS}秒）"
  STATUS="InProgress"
  ELAPSED=0
  while [[ "$STATUS" == "InProgress" || "$STATUS" == "Pending" ]] && [[ $ELAPSED -lt $SSM_WAIT_SECONDS ]]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    STATUS=$(aws ssm get-command-invocation \
      --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
      --query 'Status' --output text 2>/dev/null || echo "InProgress")
  done
  OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' --output text 2>/dev/null || echo "")
  if [[ "$OUTPUT" == *"DB_REACHABLE_OK"* ]]; then
    pass "SSM経由でRDSへのTCP到達性を確認（コマンド出力: ${OUTPUT//$'\n'/ }）"
  else
    fail "RDSへの到達性確認に失敗（ステータス: $STATUS / 出力: ${OUTPUT:-なし}）"
  fi
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"
echo "※ RDS・NATゲートウェイは時間課金です。確認が終わったら terraform destroy を忘れずに。"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
