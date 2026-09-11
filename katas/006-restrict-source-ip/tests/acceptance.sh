#!/usr/bin/env bash
#
# 006-restrict-source-ip 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. outputs.tf に、以下の値を出力するよう定義しておくこと
#        - instance_id / public_ip / security_group_id
#   3. 本スクリプトを実行する端末のグローバルIPが、セキュリティグループの
#      許可IPと一致している必要がある（送信元を絞り込んでいるため）
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
SG_ID=$(terraform -chdir="$TF_DIR" output -raw security_group_id 2>/dev/null || echo "")

if [[ -z "$WEB_IP" || -z "$SG_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義を確認してください。"
  exit 1
fi

echo "== 実行環境のグローバルIPを検出 =="
MY_IP=$(curl -s --connect-timeout "$CONNECT_TIMEOUT" https://checkip.amazonaws.com | tr -d '[:space:]')
if [[ -z "$MY_IP" ]]; then
  echo "グローバルIPの検出に失敗しました。ネットワーク接続を確認してください。"
  exit 1
fi
echo "WebサーバーIP: $WEB_IP / SG: $SG_ID / 検出した自分のIP: ${MY_IP}/32"
echo

echo "== テスト1: インバウンドルールが自分のIPの/32のみを許可しているか =="
MATCHING_RULE=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].IpRanges[?CidrIp=='${MY_IP}/32']" \
  --output text)
OTHER_CIDRS=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].IpRanges[?CidrIp!='${MY_IP}/32']" \
  --output text)
if [[ -n "$MATCHING_RULE" && -z "$OTHER_CIDRS" ]]; then
  pass "許可CIDRは ${MY_IP}/32 のみ"
else
  fail "期待通りのCIDRになっていません（自分のIP許可: $([[ -n "$MATCHING_RULE" ]] && echo あり || echo なし) / それ以外のCIDR: ${OTHER_CIDRS:-なし}）"
fi
echo

echo "== テスト2: HTTPアクセスできるか =="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$CONNECT_TIMEOUT" "http://${WEB_IP}/" || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
  pass "HTTPステータスコード: $HTTP_CODE"
else
  fail "HTTPアクセス失敗 (ステータス: $HTTP_CODE)。本スクリプトの実行元IPが許可IPと異なる可能性があります"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
