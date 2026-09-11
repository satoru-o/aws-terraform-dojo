#!/usr/bin/env bash
#
# 004-user-data-nginx 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. まだ terraform output を定義していないため、インスタンスID・
#      セキュリティグループID・パブリックIPを自分で確認し、環境変数として渡して実行すること
#        例) INSTANCE_ID=i-xxxx SG_ID=sg-xxxx WEB_IP=xx.xx.xx.xx ./tests/acceptance.sh
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

: "${INSTANCE_ID:?環境変数 INSTANCE_ID を指定してください}"
: "${SG_ID:?環境変数 SG_ID を指定してください}"
: "${WEB_IP:?環境変数 WEB_IP を指定してください}"

CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "対象インスタンス: $INSTANCE_ID / SG: $SG_ID / WebサーバーIP: $WEB_IP"
echo

echo "== テスト1: running状態、かつSGが80番のみ許可して紐付いているか =="
STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)
ATTACHED=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[?GroupId=='${SG_ID}']" \
  --output text)
PORT80_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`]" \
  --output text)
OTHER_PORT_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort!=\`80\`]" \
  --output text)
if [[ "$STATE" == "running" && -n "$ATTACHED" && -n "$PORT80_RULES" && -z "$OTHER_PORT_RULES" ]]; then
  pass "インスタンスは running、SGは80番のみ許可して紐付いている"
else
  fail "インスタンス状態: $STATE / SG紐付け: $([[ -n "$ATTACHED" ]] && echo あり || echo なし) / 80番ルール: $([[ -n "$PORT80_RULES" ]] && echo あり || echo なし) / 80番以外のルール: ${OTHER_PORT_RULES:-なし}"
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
