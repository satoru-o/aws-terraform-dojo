# bootstrap/

道場全体で使う、Terraform state保存用S3バケットを**一度だけ**手動で作るためのディレクトリです。

## なぜTerraformで管理しないのか

state保存先のバケット自体をTerraformで作ろうとすると、
「stateを保存する場所がまだない状態でstateを作る」という
鶏と卵の矛盾が起きます。そのため、backend用のリソースだけは
aws-cliで手動作成するのが定石です。

## 実行方法

```bash
export AWS_PROFILE=aws-terraform-dojo   # 自分のプロファイル名に置き換え可
chmod +x bootstrap-backend.sh
./bootstrap-backend.sh
```

スクリプト内の `BUCKET_NAME` と `PROJECT_TAG` はサンプル値になっているので、
実行前に自分のプロジェクトに合わせて書き換えてください
(バケット名はグローバルで一意である必要があります)。

## 実行タイミング

- 道場を新しいAWSアカウント/プロファイルで始めるとき
- 最初の1回のみ。以降は各kataがこのバケットを共有して使う

## 各kataからの参照方法

各 `katas/<段位>/<kata名>/terraform/backend.tf` で以下のように参照します。

```hcl
terraform {
  backend "s3" {
    bucket       = "aws-terraform-dojo-tfstate"
    key          = "katas/<kata-name>/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true  # Terraform 1.10+ のS3ネイティブロック機能
  }
}
```

`profile` はbackend.tfに書かず、実行時に `export AWS_PROFILE=aws-terraform-dojo` で渡す運用に統一しています。
`key` はkataごとに一意にすること(state同士が衝突しないように)。

## 注意事項

- このバケットを削除するとすべてのkataのstateが失われます。取り扱い注意。
- バージョニングが有効なので、誤ってstateを壊しても過去バージョンから復旧可能です。