# 005-outputs: outputブロックで値を出力する

## 背景・目的

`004-user-data-nginx` までで、EC2インスタンス上にHTTPサーバーが立ち上がる構成ができた。本お題では最後の仕上げとして `output` ブロックを追加し、`terraform apply` 後に必要な値（インスタンスID・パブリックIP・セキュリティグループID）を `terraform output` コマンドで取得できるようにする。このお題で新しく学ぶ概念は「output」1つだけに絞る。

これまでの `002`〜`004` では、受入テストの実行時にインスタンスIDなどを自分で調べて環境変数に渡す必要があった。本お題からは、`tests/acceptance.sh` が `terraform output` を使って自動的に値を取得できるようになる。この自動採点が通ることを確認する。

## 登場する概念（詰まったら調べる）

- **output**: `terraform apply` 完了後に、作成したリソースの属性値（IDやIPアドレスなど）を画面に表示したり、`terraform output` コマンドで取得したりするための仕組み。リソースブロックの外に `output "任意の名前" { value = ... }` という形で書く。

## 進め方の手がかり

1. `004-user-data-nginx/terraform/` の中身を `005-outputs/terraform/` にコピーする
2. `output` ブロックを3つ追加する（インスタンスID・パブリックIP・セキュリティグループID）
3. `terraform apply` を実行し、`terraform output` で3つの値が正しく表示されることを確認する
4. `tests/acceptance.sh` を実行し、自動採点がすべてPASSすることを確認する

## 要件（Must）

- [ ] セキュリティグループがTCP80番のみを許可していること（`004-user-data-nginx` の内容を引き続き維持する）
- [ ] インスタンスの80番ポートにHTTPアクセスすると、何らかのレスポンス（2xx/3xx系）が返ること（インスタンスが起動しrunning状態であること、`user_data`でHTTPサーバーが自動起動していることの確認を兼ねる）
- [ ] `terraform output` で、以下3つの値を出力すること
  - `instance_id`: EC2インスタンスのID
  - `public_ip`: EC2インスタンスの（パブリックまたは到達可能な）IPアドレス
  - `security_group_id`: セキュリティグループのID

## 制約（禁止事項）

- インバウンドルールに80番以外のポートを追加しないこと
- 使用可能なAWSサービスはEC2（デフォルトVPCの利用を含む）・セキュリティグループに限定する
- output名は上記3つの名前（`instance_id` / `public_ip` / `security_group_id`）に厳密に合わせること（`tests/acceptance.sh` がこの名前で値を取得するため）

## 推奨（Should）

- `outputs.tf` というファイル名に分離する（必須ではないが、他ファイルとの見通しがよくなる）
- 各 `output` に `description` を付ける

## 受入テスト

`tests/acceptance.sh` を参照。概要は以下の通り。本お題から `terraform output` を使った自動採点になる。

| # | 検証内容 | コマンド例 | 期待結果 |
|---|---|---|---|
| 1 | セキュリティグループのインバウンドルールが80番のみを許可している | `terraform output` → `aws ec2 describe-security-groups` | 80番の許可ルールが1件以上、かつ80番以外の許可ルールが0件 |
| 2 | HTTPアクセスで応答が返る | `terraform output` → `curl -o /dev/null -w "%{http_code}"` | HTTPステータスコードが2xx系または3xx系 |

`terraform output` の3つの値（`instance_id` / `public_ip` / `security_group_id`）は、いずれか1つでも取得できなければ `tests/acceptance.sh` がその時点で異常終了する（前提条件チェック）。

## スコープ外

- 送信元IPを絞り込む設計（`006-restrict-source-ip` 以降で扱う）
- ALB・Auto Scaling Group・複数AZ構成（今後のお題で扱う）
- モジュール化・tfvars分離・リモートステート（今後のお題で扱う）

## 難易度

スコア: 11（S=1, R=2, 深さ=1, エッジ=1, T=2）
カテゴリ: なし
