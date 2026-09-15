terraform {
  required_version = "~> 1.16"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "aws-terraform-dojo-tfstate"
    key = "katas/007-bastion-sg-reference/terraform.tfstate"
    region = "ap-northeast-1"
    use_lockfile = true
    encrypt = true
    profile = "aws-terraform-dojo"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project = "007-bastion-sg-reference"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_instance" "dojo-007-ec2-web" {
  ami = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.dojo-007-sg-web.id]

  user_data = <<-EOF
              #!/bin/bash
              # システムパッケージ最新化
              dnf update -y

              # nginxをインストール
              dnf install -y nginx

              # nginxを起動
              systemctl start nginx

              # nginx自動起動を有効化
              systemctl enable nginx

              echo "😺隠れねこちゃん"

              EOF

  tags = {
    Name = "dojo-007-ec2-web"
  }
}

resource "aws_instance" "dojo-007-ec2-bastion" {
  ami = var.ami
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.dojo-007-sg-bastion.id]

  tags = {
    Name = "dojo-007-ec2-bastion"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "dojo-007-sg-bastion" {
  name = "dojo-007-sg-bastion"
  description = "Security Group for Bastion Server"
}

# 踏み台サーバー(bastion)へのSSH許可
resource "aws_vpc_security_group_ingress_rule" "dojo-007-sgir-bastion" {
  security_group_id = aws_security_group.dojo-007-sg-bastion.id
  cidr_ipv4 = "${var.my_ip}/32"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
}

# 踏み台のアウトバウンド
resource "aws_vpc_security_group_egress_rule" "dojo-007-sger-bastion" {
  security_group_id = aws_security_group.dojo-007-sg-bastion.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "dojo-007-sg-web" {
  name = "dojo-007-sg-web"
  description = "Security Group for Web Server"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "dojo-007-sgir-web" {
  security_group_id = aws_security_group.dojo-007-sg-web.id

  # 接続元に踏み台のセキュリティグループIDを指定
  referenced_security_group_id = aws_security_group.dojo-007-sg-bastion.id

  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "dojo-007-sger-web" {
  security_group_id = aws_security_group.dojo-007-sg-web.id

  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}