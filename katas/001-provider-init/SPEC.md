# 001-provider-init: providerブロックを書いてterraform initを通す

## 背景・目的

道場の最初の一歩。AWSリソースは一切作らず、「Terraformプロジェクトを立ち上げ、`terraform init` を通す」というワークフローそのものに慣れることだけをゴールとする。

このお題ではコスト面のリスクは一切ない（AWSリソースを作成しないため課金も発生しない）。安心して `terraform init` を何度も実行し、エラーメッセージの読み方に慣れてほしい。

次のお題 `002-ec2-only` から、ここで作った土台の上にリソースを1つずつ積み上げていく。

## 登場する概念（詰まったら調べる）

- **terraform ブロック**: Terraform自体の設定（使用するプロバイダの種類・バージョン、Terraform本体の必須バージョンなど）を書く場所。`required_providers` の中で「AWSを操作したいので `hashicorp/aws` プロバイダを使う」と宣言する。
- **provider "aws" ブロック**: 「どのリージョンのAWSを操作するか」などプロバイダ固有の設定を書く場所。このブロックがあることで、以降のkataで書くAWSリソースがどのリージョンに作られるかが決まる。
- **terraform init**: `terraform` ブロック・`provider` ブロックの内容を元に、必要なプロバイダプラグインをダウンロードしてくるコマンド。実行すると `.terraform/` ディレクトリと `.terraform.lock.hcl` というファイルが生成される。`.terraform/` はダウンロードされたプラグイン本体なのでgit管理対象外（`.gitignore`済み）、`.terraform.lock.hcl` はバージョン固定のための記録ファイルでgit管理対象。

## 進め方の手がかり

1. `terraform/` 配下に `.tf` ファイルを1つ作成する（ファイル名は自由。`main.tf` など）
2. `terraform` ブロックの中に `required_providers` を書き、`hashicorp/aws` プロバイダを指定する
3. `provider "aws"` ブロックを書き、リージョンを `ap-northeast-1` に設定する
4. `terraform init` を実行し、エラーなく完了することを確認する
5. `terraform validate` を実行し、文法エラーがないことを確認する

## 要件（Must）

- [ ] `terraform init` がエラーなく完了すること
- [ ] `terraform validate` がエラーなく完了すること

> `hashicorp/aws` プロバイダの指定、リージョンの指定、`resource` ブロックを書かないことなどは、いずれも「コードの書き方」に関する申し合わせであり、`terraform init`/`terraform validate` は文法チェックしかしないため、これらの充足を`tests/acceptance.sh`で機械的に検証することはできない（AWSリソースを一切作らないこのお題では、状態を問い合わせる先すらない）。そのため以下の「推奨（Should）」に位置づける。

## 制約（禁止事項）

特になし。本お題はAWSリソースを作成しないため、`0.0.0.0/0`の全開放やIAMの過剰権限付与といった典型的な禁止事項が発生しうる余地がない。

## 推奨（Should）

- `terraform { required_providers { ... } }` を定義し、`hashicorp/aws` プロバイダを指定する
- `provider "aws" { ... }` ブロックを定義し、リージョンとして `ap-northeast-1` を指定する（以降のkataとリージョンを揃えるため）
- `resource` ブロックはまだ書かない（次のお題 `002-ec2-only` からEC2インスタンスを追加していく）
- backend（リモートステート）を設定する場合は `bootstrap/README.md` を参照し、`key` をこのkata専用の値にする（必須ではない。ローカルstateのままでも本お題のMust要件は満たせる）
- ファイルを分割する場合、`terraform` ブロックと `provider` ブロックは慣例的に `main.tf`（または `versions.tf`/`provider.tf`）にまとめる

## 受入テスト

`tests/acceptance.sh` を参照。概要は以下の通り。

| # | 検証内容 | コマンド例 | 期待結果 |
|---|---|---|---|
| 1 | `terraform init` / `terraform validate` が成功する | `terraform init` / `terraform validate` | 両方とも終了コード0 |

このお題ではAWS API呼び出しを伴う検証は行わない（AWSリソースが存在しないため）。

## スコープ外

- AWSリソースの作成全般（`002-ec2-only` 以降で扱う）
- variables.tf・outputs.tf の使用（後のkatasで扱う）
- backendの必須化（推奨に留める）

## 難易度スコア

1.5点（S=0, R=0, 深さ=0, エッジ=0, T=1）
