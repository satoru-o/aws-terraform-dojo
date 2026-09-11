#!/usr/bin/env bash
#
# 009-nat-gateway 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. outputs.tf に、301までの値に加えて以下を出力しておくこと
#        - nat_gateway_id / private_route_table_id
#
# コストに関する注意:
#   NATゲートウェイは時間課金です。確認が終わったら `terraform destroy` してください。
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
PUBLIC_SUBNET_ID=$(terraform -chdir="$TF_DIR" output -raw public_subnet_id 2>/dev/null || echo "")
NAT_GATEWAY_ID=$(terraform -chdir="$TF_DIR" output -raw nat_gateway_id 2>/dev/null || echo "")
PRIVATE_RT_ID=$(terraform -chdir="$TF_DIR" output -raw private_route_table_id 2>/dev/null || echo "")

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" || -z "$BASTION_INSTANCE_ID" || -z "$BASTION_SG_ID" || -z "$PUBLIC_SUBNET_ID" || -z "$NAT_GATEWAY_ID" || -z "$PRIVATE_RT_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義を確認してください。"
  exit 1
fi
echo "NAT: $NAT_GATEWAY_ID / PrivateRT: $PRIVATE_RT_ID"
echo

echo "== テスト1: WebサーバーSGのインバウンド80番が踏み台SGのみを参照しているか =="
SG_REF=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].UserIdGroupPairs[?GroupId=='${BASTION_SG_ID}']" \
  --output text)
CIDR_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].IpRanges[]" \
  --output text)
if [[ -n "$SG_REF" && -z "$CIDR_RULES" ]]; then
  pass "送信元は踏み台SGの参照のみ（CIDR許可なし）"
else
  fail "期待通りの設定になっていません（踏み台SG参照: $([[ -n "$SG_REF" ]] && echo あり || echo なし) / CIDR許可: ${CIDR_RULES:-なし}）"
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

echo "== テスト3: Web/踏み台がrunning状態でパブリックサブネットに配置され、IGWへの経路があるか =="
WEB_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
BASTION_STATE=$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
WEB_SUBNET=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].SubnetId' --output text)
BASTION_SUBNET=$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID" --query 'Reservations[0].Instances[0].SubnetId' --output text)
PUBLIC_IGW_ROUTE=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID}" \
  --query "RouteTables[0].Routes[?starts_with(GatewayId, 'igw-') && DestinationCidrBlock=='0.0.0.0/0']" \
  --output text)
if [[ "$WEB_STATE" == "running" && "$BASTION_STATE" == "running" && "$WEB_SUBNET" == "$PUBLIC_SUBNET_ID" && "$BASTION_SUBNET" == "$PUBLIC_SUBNET_ID" && -n "$PUBLIC_IGW_ROUTE" ]]; then
  pass "Web/踏み台はrunning状態でパブリックサブネットに配置され、IGWへのデフォルトルートがある"
else
  fail "Web状態: $WEB_STATE / 踏み台状態: $BASTION_STATE / Webサブネット: $WEB_SUBNET / 踏み台サブネット: $BASTION_SUBNET / IGWルート: $([[ -n "$PUBLIC_IGW_ROUTE" ]] && echo あり || echo なし)"
fi
echo

echo "== テスト4: プライベートRTがNAT経由の0.0.0.0/0ルートを持ち、IGWへの直接ルートを持たないか =="
NAT_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query "RouteTables[0].Routes[?NatGatewayId=='${NAT_GATEWAY_ID}' && DestinationCidrBlock=='0.0.0.0/0']" \
  --output text)
IGW_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query "RouteTables[0].Routes[?starts_with(GatewayId, 'igw-')]" \
  --output text)
if [[ -n "$NAT_ROUTE" && -z "$IGW_ROUTE" ]]; then
  pass "プライベートRTはNAT経由の0.0.0.0/0ルートのみを持つ"
else
  fail "NATルート: $([[ -n "$NAT_ROUTE" ]] && echo あり || echo なし) / IGWルート: ${IGW_ROUTE:-なし}"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"
echo "※ NATゲートウェイは時間課金です。確認が終わったら terraform destroy を忘れずに。"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
