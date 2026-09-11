#!/usr/bin/env bash
#
# 003-security-group 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. まだ terraform output を定義していないため、インスタンスID・
#      セキュリティグループIDを自分で確認し、環境変数として渡して実行すること
#        例) INSTANCE_ID=i-xxxx SG_ID=sg-xxxx ./tests/acceptance.sh
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

: "${INSTANCE_ID:?環境変数 INSTANCE_ID を指定してください}"
: "${SG_ID:?環境変数 SG_ID を指定してください}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "対象インスタンス: $INSTANCE_ID / SG: $SG_ID"
echo

echo "== テスト1: インバウンドルールが80番のみか =="
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

echo "== テスト2: セキュリティグループがEC2インスタンスに紐付いているか =="
ATTACHED=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[?GroupId=='${SG_ID}']" \
  --output text)
if [[ -n "$ATTACHED" ]]; then
  pass "セキュリティグループがインスタンスに紐付いている"
else
  fail "セキュリティグループがインスタンスに紐付いていない"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
