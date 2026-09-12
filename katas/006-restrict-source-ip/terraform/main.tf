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
    key = "katas/006-restrict-source-ip/terraform.tfstate"
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
      Project = "006-restrict-source-ip"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_instance" "dojo-006-ec2" {
  ami = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.dojo-006-sg.id]

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
    Name = "dojo-006-ec2"
  }
}

resource "aws_security_group" "dojo-006-sg" {
  description = "Allows Port 80"
  ingress {
    cidr_blocks = ["180.20.97.8/32"]
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dojo-006-sg"
  }
}