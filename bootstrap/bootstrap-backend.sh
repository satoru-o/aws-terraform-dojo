#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# bootstrap-backend.sh
#
# 目的:
#   Terraformのstate(実行結果の記録ファイル)を保存するための
#   S3バケットを、初回に一度だけ手動で作成する。
#
#   このスクリプトはTerraform管理"外"で実行する。
#   (state置き場自体をTerraformで作ろうとすると
#    「卵が先か鶏が先か」問題になるため、bootstrapは
#    aws-cliで手動実行するのが定石)
#
# 前提:
#   - aws-cli設定済みで、AWS_PROFILEに対応するプロファイルが
#     ~/.aws/config / ~/.aws/credentials に登録済みであること
#   - バケット名はグローバルで一意である必要がある
#     (実行前に自分の環境に合わせて調整すること)
#
# 実行方法:
#   export AWS_PROFILE=aws-terraform-dojo
#   ./bootstrap-backend.sh
# =============================================================

: "${AWS_PROFILE:?AWS_PROFILE を先に export してください (例: export AWS_PROFILE=aws-terraform-dojo)}"

BUCKET_NAME="aws-terraform-dojo-tfstate"
REGION="ap-northeast-1"
PROJECT_TAG="aws-terraform-dojo"

echo "==> 使用プロファイル: ${AWS_PROFILE}"
echo "==> S3バケット作成: ${BUCKET_NAME} (region: ${REGION})"
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

# バージョニングを有効化する理由:
#   state破損・誤削除が起きた際に、過去バージョンから復旧できるようにするため。
#   Terraformのstateは実質的に「インフラの唯一の記録」であり、
#   壊れると復旧が非常に困難になるため、これは実質必須の設定。
echo "==> バージョニング有効化(state破損時の復旧用)"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

# タグ付けの理由:
#   このバケットが「何のために」「誰が(手動で)」作ったものかを
#   AWSコンソール上でも一目でわかるようにするため。
#   ManagedBy=manual-bootstrap を付けることで、
#   後から「これはTerraform管理外の特別な存在」と識別できる。
echo "==> タグ付け"
aws s3api put-bucket-tagging \
  --bucket "${BUCKET_NAME}" \
  --tagging "{
    \"TagSet\": [
      {\"Key\": \"Project\", \"Value\": \"${PROJECT_TAG}\"},
      {\"Key\": \"ManagedBy\", \"Value\": \"manual-bootstrap\"},
      {\"Key\": \"Purpose\", \"Value\": \"terraform-state\"}
    ]
  }"

echo "==> 完了。作成されたバケット: ${BUCKET_NAME}"
echo ""
echo "次のステップ:"
echo "  各kataのbackend.tfで以下のように参照してください:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket       = \"${BUCKET_NAME}\""
echo "      key          = \"katas/<kata-name>/terraform.tfstate\""
echo "      region       = \"${REGION}\""
echo "      use_lockfile = true  # Terraform 1.10+ のS3ネイティブロック"
echo "    }"
echo "  }"
echo ""
echo "  ※ profile は backend.tf に書かず、実行時に"
echo "    export AWS_PROFILE=${AWS_PROFILE} で渡す運用に統一しています。"