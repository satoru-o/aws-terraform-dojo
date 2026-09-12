#!/usr/bin/env bash
#
# 007-bastion-sg-reference 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. outputs.tf に、以下の値を出力するよう定義しておくこと
#        - instance_id / public_ip / security_group_id （Webサーバー側）
#        - bastion_instance_id / bastion_security_group_id （踏み台サーバー側）
#   3. 本スクリプトは「踏み台サーバー以外からは失敗する」ことを検証するため、
#      踏み台サーバー自身ではない端末（通常のローカル環境）から実行すること
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== terraform output の取得 =="
WEB_IP=$(terraform -chdir="$TF_DIR" output -raw public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw instance_id 2>/dev/null || echo "")
SG_ID=$(terraform -chdir="$TF_DIR" output -raw security_group_id 2>/dev/null || echo "")
BASTION_INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw bastion_instance_id 2>/dev/null || echo "")
BASTION_SG_ID=$(terraform -chdir="$TF_DIR" output -raw bastion_security_group_id 2>/dev/null || echo "")

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" || -z "$BASTION_INSTANCE_ID" || -z "$BASTION_SG_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義を確認してください。"
  exit 1
fi
echo "Web: $INSTANCE_ID ($WEB_IP) / Web SG: $SG_ID / 踏み台: $BASTION_INSTANCE_ID / 踏み台 SG: $BASTION_SG_ID"
echo

echo "== テスト1: 両インスタンスがrunning状態で、WebサーバーSGが踏み台SGのみを参照しているか =="
WEB_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
BASTION_STATE=$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
SG_REF=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].UserIdGroupPairs[] | [?GroupId=='${BASTION_SG_ID}']" \
  --output text)
CIDR_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].IpRanges[]" \
  --output text)
if [[ "$WEB_STATE" == "running" && "$BASTION_STATE" == "running" && -n "$SG_REF" && -z "$CIDR_RULES" ]]; then
  pass "両インスタンスがrunning、送信元は踏み台SGの参照のみ（CIDR許可なし）"
else
  fail "Web状態: $WEB_STATE / 踏み台状態: $BASTION_STATE / 踏み台SG参照: $([[ -n "$SG_REF" ]] && echo あり || echo なし) / CIDR許可: ${CIDR_RULES:-なし}"
fi
echo

echo "== テスト2: 外部からWebサーバーへのHTTP直接アクセスが失敗するか =="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CONNECT_TIMEOUT" "http://${WEB_IP}/" || echo "000")
if [[ ! "$HTTP_CODE" =~ ^[23] ]]; then
  pass "外部からの直接アクセスは失敗（ステータス: ${HTTP_CODE}）"
else
  fail "外部から直接アクセスできてしまいました（ステータス: ${HTTP_CODE}）。送信元制限を見直してください"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
