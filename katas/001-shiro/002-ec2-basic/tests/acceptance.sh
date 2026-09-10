#!/usr/bin/env bash
#
# shiro-01 / 002-ec2-basic 受入テスト雛形
#
# 前提:
#   1. terraform/ 配下で `terraform apply` 済みであること
#   2. 自分の実装の outputs.tf に、以下の値を出力するよう定義しておくこと
#        - web_server_instance_id
#        - web_server_public_ip     (Webサーバーの到達可能なIPアドレス)
#        - web_server_sg_id         (Webサーバー用セキュリティグループのID)
#   3. 環境変数 BASTION_IP に踏み台サーバーのIPアドレスを設定しておくこと
#      （terraform outputに bastion_ip を用意している場合はそちらを優先して使う）
#   4. 踏み台サーバーにSSHでログインできる秘密鍵のパスを SSH_KEY_PATH に設定すること
#
# 実行方法（想定）:
#   - テスト1〜5は「踏み台サーバー上」、または踏み台サーバーへの疎通を代理できる環境から実行する
#   - テスト6（踏み台以外からの到達不可の確認）は、踏み台サーバーではない環境から実行する
#
# 本スクリプトはあくまで雛形です。自分の実装（output名、AMIのログインユーザー名など）に
# 合わせて書き換えてください。TODOコメントの箇所は特に確認すること。

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
# TODO: 使用するAMIに合わせてログインユーザー名を変更する（Amazon Linux: ec2-user, Ubuntu: ubuntu 等）
SSH_USER="${SSH_USER:-ec2-user}"
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
BASTION_IP="${BASTION_IP:-$(terraform -chdir="$TF_DIR" output -raw bastion_ip 2>/dev/null || echo "")}"

if [[ -z "$WEB_IP" || -z "$INSTANCE_ID" || -z "$SG_ID" ]]; then
  echo "terraform output が取得できません。outputs.tf の定義、または上記の変数名を確認してください。"
  exit 1
fi
if [[ -z "$BASTION_IP" ]]; then
  echo "踏み台サーバーのIPアドレスが取得できません。環境変数 BASTION_IP を設定するか、"
  echo "outputs.tf に bastion_ip を追加してください。"
  exit 1
fi

echo "WebサーバーIP: $WEB_IP / InstanceID: $INSTANCE_ID / SG: $SG_ID / 踏み台IP: $BASTION_IP"
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

echo "== テスト2: インバウンドルールに全開放(0.0.0.0/0, ::/0)が無いか =="
OPEN_RULES=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']||Ipv6Ranges[?CidrIpv6=='::/0']]" \
  --output text)
if [[ -z "$OPEN_RULES" ]]; then
  pass "全開放ルールは存在しない"
else
  fail "全開放ルールが見つかりました: $OPEN_RULES"
fi
echo

echo "== テスト3: 22番・80番の送信元が踏み台IP(/32)に限定されているか =="
for PORT in 22 80; do
  ALLOWED_CIDR=$(aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`${PORT}\`].IpRanges[].CidrIp" \
    --output text)
  if [[ "$ALLOWED_CIDR" == "${BASTION_IP}/32" ]]; then
    pass "${PORT}番の許可CIDRは ${BASTION_IP}/32 のみ"
  else
    fail "${PORT}番の許可CIDR: '${ALLOWED_CIDR}' (期待値: ${BASTION_IP}/32)"
  fi
done
echo

echo "== テスト4: 踏み台サーバーからSSH接続できるか =="
# NOTE: このテストは踏み台サーバー上で実行するか、-J (ProxyJump) 経由で実行すること
if ssh -o ConnectTimeout="$CONNECT_TIMEOUT" -o StrictHostKeyChecking=no \
  -i "$SSH_KEY_PATH" "${SSH_USER}@${WEB_IP}" "echo ok" &>/dev/null; then
  pass "踏み台経由でのSSH接続に成功"
else
  fail "踏み台経由でのSSH接続に失敗"
fi
echo

echo "== テスト5: 踏み台サーバーからHTTPアクセスできるか =="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$CONNECT_TIMEOUT" "http://${WEB_IP}/" || echo "000")
if [[ "$HTTP_CODE" =~ ^[23] ]]; then
  pass "HTTPステータスコード: $HTTP_CODE"
else
  fail "HTTPアクセス失敗 (ステータス: $HTTP_CODE)"
fi
echo

echo "== テスト6: 踏み台以外からはSSH/HTTPともに到達できないか =="
echo "  ※このテストは『踏み台サーバーではない環境』から実行すること"
if nc -z -w "$CONNECT_TIMEOUT" "$WEB_IP" 22 &>/dev/null; then
  fail "踏み台以外からSSH(22番)に到達できてしまう"
else
  pass "踏み台以外からSSH(22番)への到達は失敗（期待通り）"
fi

if nc -z -w "$CONNECT_TIMEOUT" "$WEB_IP" 80 &>/dev/null; then
  fail "踏み台以外からHTTP(80番)に到達できてしまう"
else
  pass "踏み台以外からHTTP(80番)への到達は失敗（期待通り）"
fi
echo

echo "======================================"
echo " 結果: PASS=$PASS FAIL=$FAIL"
echo "======================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
