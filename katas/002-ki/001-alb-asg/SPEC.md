# 002-ki / 001-alb-asg: ALB + Auto Scaling Group + 複数AZ構成

> **Status: 準備中** — このお題のSPEC.mdはまだ確定していません。
> `templates/SPEC_TEMPLATE.md` に沿って、001-shiro/001-ec2-hello・002-ec2-basic の内容が完了した後に詳細化します。

## 想定テーマ（下書き）

Application Load Balancer配下に、複数AZにまたがるAuto Scaling Groupを構成し、
ヘルスチェックに基づいてインスタンスの入れ替え・分散が行われることを検証するお題を想定しています。

001-shiro/001-ec2-hello・002-ec2-basic（単一EC2 + SG）で習得した内容の上に、以下のような要素が加わる見込みです。

- 複数AZへのリソース配置
- ALBのターゲットグループ・ヘルスチェック設定
- Auto Scaling Groupのスケーリングポリシー
- リソース間の依存関係（ALB → ターゲットグループ → ASG）の記述

詳細な要件・制約・受入テストは、確定後に本ファイルへ追記します。
