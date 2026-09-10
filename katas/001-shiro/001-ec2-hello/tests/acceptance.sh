#!/usr/bin/env bash
#
# shiro-01 / 001-ec2-hello 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. 自分の実装の outputs.tf に、以下の値を出力するよう定義しておくこと
#        - web_server_instance_id
#        - web_server_public_ip     (Webサーバーの到達可能なIPアドレス)
#        - web_server_sg_id         (Webサーバー用セキュリティグループのID)
#
# 実行方法（想定）:
#   - ローカル環境（インターネット経由でWebサーバーに到達できる環境）から実行する
#
# 本スクリプトはあくまで雛形です。自分の実装（output名など）に合わせて書き換えてください。
# TODOコメントの箇所は特に確認すること。

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== terraform output の取得 =="
# TODO: 自分の実装のoutput名がこれと異なる場合は書き換える
WEB_IP=$(terraform -chdir="$TF_DIR" output -raw web_server_public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw web_server_instance_id 2>/dev/null || echo "")
SG_ID=$(terraform -chdir="$TF_DIR" output -raw web_server_sg_id 2>/dev/null || echo "")

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義、または上記の変数名を確認してください。"
  exit 1
fi

echo "WebサーバーIP: $WEB_IP / InstanceID: $INSTANCE_ID / SG: $SG_ID"
echo

echo "== テスト1: Webサーバーが running 状態か =="
STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)
if [[ "$STATE" == "running" ]]; then
  pass "インスタンスは running 状態"
else
  fail "インスタンスの状態: $STATE"
fi
echo

echo "== テスト2: インバウンドルールが80番のみか =="
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

echo "== テスト3: HTTPアクセスできるか =="
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
