#!/usr/bin/env bash
#
# 002-ec2-only 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. まだ terraform output を定義していないため、インスタンスIDを
#      自分で確認し、環境変数 INSTANCE_ID として渡して実行すること
#        例) INSTANCE_ID=i-xxxxxxxx ./tests/acceptance.sh
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

: "${INSTANCE_ID:?環境変数 INSTANCE_ID を指定してください（例: INSTANCE_ID=i-xxxx ./tests/acceptance.sh）}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "対象インスタンス: $INSTANCE_ID"
echo

echo "== テスト1: インスタンスが running 状態か =="
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

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
