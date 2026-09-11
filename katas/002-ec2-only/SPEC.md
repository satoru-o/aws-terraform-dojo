# 002-ec2-only: EC2インスタンスを1台起動する

## 背景・目的

`001-provider-init` で作った土台の上に、初めてAWSリソースを1つ追加する。このお題で新しく学ぶ概念は「EC2インスタンス」1つだけに絞る。セキュリティグループは作らず（デフォルトセキュリティグループのまま）、HTTPサーバーも立てない。`terraform apply` が通り、インスタンスが `running` 状態になることだけをゴールとする。

`001-provider-init` の `terraform/` の中身をコピーし、その上に `aws_instance` リソースを1つ追加する形で進めること。

## 登場する概念（詰まったら調べる）

- **EC2インスタンス**: AWS上で動く仮想サーバーそのもの。Terraformでは特定のリソースタイプ（1種類）を使って作る。VPCやサブネットは、AWSアカウントに最初から用意されている「デフォルトVPC」をそのまま使ってよく、自分で新規作成する必要はない。
- **AMI (Amazon Machine Image)**: EC2インスタンスの元になる「OSのひな形」。起動するインスタンスにはAMIのIDを指定する必要がある。AMI IDを直接ハードコードする方法と、条件を指定して検索して取得する方法（データソース）の両方がある。
  - **注意**: AMIを名前で検索する場合、Amazon Linux 2023には `al2023-ami-minimal-...` という名前の「minimal版」が存在するが、これは最小構成のため `yum`/`dnf` などの標準的なパッケージ管理コマンドが使えないことがある。次のお題以降でパッケージインストールを行うことを見据え、名前に `minimal` を**含まない**AMIを選ぶこと。
- **インスタンスタイプ**: EC2インスタンスのスペック（CPU・メモリなど）を決める設定値。無料利用枠の対象になりやすい `t3.micro` や `t2.micro` などを調べるとよい。

## 進め方の手がかり

1. `001-provider-init/terraform/` の中身を `002-ec2-only/terraform/` にコピーする
2. `aws_instance` リソースを1つ、最小限の設定（AMI・インスタンスタイプ）だけで追加する
3. `terraform plan` がエラーなく通ることを確認する
4. `terraform apply` を実行し、AWSコンソールまたは `aws ec2 describe-instances` でインスタンスが `running` になっていることを確認する
5. 動作確認が終わったら、次のお題に進む前に `terraform destroy` してよい（課金を抑えるため）

## 要件（Must）

- [ ] EC2インスタンスを1台起動し、`running` 状態になること
- [ ] インスタンスに紐付くセキュリティグループがデフォルトセキュリティグループのみであること（新規セキュリティグループを作成・アタッチしない）
- [ ] 使用しているAMIの名前に `minimal` が含まれないこと

## 制約（禁止事項）

- セキュリティグループ・IAMロールなど、EC2インスタンス以外のAWSリソースを新規作成しないこと（デフォルトのVPC・デフォルトSGはそのまま使ってよい）
- 使用可能なAWSサービスはEC2（デフォルトVPCの利用を含む）に限定する
- `user_data` は設定しないこと（次のお題 `004-user-data-nginx` で扱う）

## 推奨（Should）

- リソース名には `dojo-shiro-` などのプレフィックスを付け、他のお題のリソースと区別できるようにする
- `Name` タグを付けておく（例: `Name = "dojo-shiro-ec2"`）。まだ `terraform output` を使わないため、動作確認やテスト実行時にタグで検索すると探しやすい
- AMI IDやインスタンスタイプは変数（`variables.tf`）に切り出す

## 受入テスト

`tests/acceptance.sh` を参照。概要は以下の通り。まだ `terraform output` を定義していないため、`terraform apply` 後に自分でインスタンスIDを確認し、環境変数として渡して実行する。

| # | 検証内容 | コマンド例 | 期待結果 |
|---|---|---|---|
| 1 | インスタンスが `running` 状態である | `aws ec2 describe-instances --instance-ids "$INSTANCE_ID"` | `State.Name` = `running` |
| 2 | セキュリティグループがデフォルトのみである | `aws ec2 describe-instances` の `SecurityGroups` | `GroupName` が `default` のみ |
| 3 | AMI名に `minimal` を含まない | `describe-instances` で取得した `ImageId` を `aws ec2 describe-images` に渡す | `Name` に `minimal`（大小文字問わず）を含まない |

## スコープ外

- セキュリティグループの作成・アタッチ（`003-security-group` で扱う）
- HTTPサーバーの起動（`004-user-data-nginx` で扱う）
- `terraform output`（`005-outputs` で扱う）
- ALB・Auto Scaling Group・複数AZ構成（今後のお題で扱う）

## 難易度

スコア: 7.5（S=1, R=1, 深さ=0, エッジ=0, T=3）
カテゴリ: なし
