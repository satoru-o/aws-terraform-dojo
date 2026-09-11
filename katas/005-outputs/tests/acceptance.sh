#!/usr/bin/env bash
#
# 005-outputs 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. outputs.tf（またはmain.tf内）に、以下の値を出力するよう定義しておくこと
#        - instance_id
#        - public_ip           (Webサーバーの到達可能なIPアドレス)
#        - security_group_id
#
# 実行方法（想定）:
#   - ローカル環境（インターネット経由でWebサーバーに到達できる環境）から実行する
#
# 本スクリプトはあくまで雛形です。自分の実装（output名など）に合わせて書き換えてください。

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

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義、またはoutput名（instance_id / public_ip / security_group_id）を確認してください。"
  exit 1
fi

echo "WebサーバーIP: $WEB_IP / InstanceID: $INSTANCE_ID / SG: $SG_ID"
echo

echo "== テスト1: セキュリティグループのインバウンドルールが80番のみか =="
OTHER_PORT_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort!=\`80\`]" \
  --output text)
if [[ -z "$OTHER_PORT_RULES" ]]; then
  pass "80番以外の許可ルールは存在しない"
else
  fail "80番以外の許可ルールが見つかりました: $OTHER_PORT_RULES"
fi
echo

echo "== テスト2: HTTPアクセスできるか =="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$CONNECT_TIMEOUT" "http://${WEB_IP}/" || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
  pass "HTTPステータスコード: $HTTP_CODE"
else
  fail "HTTPアクセス失敗 (ステータス: $HTTP_CODE)"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
