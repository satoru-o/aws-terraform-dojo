#!/usr/bin/env bash
#
# 001-provider-init 受入テスト雛形
#
# 前提:
#   - terraform/ 配下に provider ブロックのみを書いた状態であること
#   - AWSリソースは作成しない（AWS API呼び出しは行わない）
#
# 本スクリプトはあくまで雛形です。自分の実装に合わせて書き換えてください。

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== テスト1: terraform init / validate が成功するか =="
if terraform -chdir="$TF_DIR" init -input=false >/tmp/tf-init.log 2>&1 \
  && terraform -chdir="$TF_DIR" validate >/tmp/tf-validate.log 2>&1; then
  pass "terraform init / validate が成功"
else
  fail "terraform init / validate が失敗（/tmp/tf-init.log, /tmp/tf-validate.log を確認）"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
