terraform {
  required_version = "~> 1.16"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "aws-terraform-dojo-tfstate"
    key          = "katas/001-ec2-hello/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true  # Terraform 1.10+ のS3ネイティブロック機能
    encrypt      = true
    profile      = "aws-terraform-dojo"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project = "001-ec2-hello"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_instance" "dojo-shiro01-ec2" {
  ami = "ami-0b2ab21b2b2d4f2e5"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.dojo-shiro01-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # システムパッケージを最新化
              dnf update -y
              
              # nginxをインストール
              dnf install -y nginx
              
              # nginxを起動
              systemctl start nginx
              
              # nginx自動起動を有効化（再起動しても起動する）
              systemctl enable nginx
              
              EOF
}

resource "aws_security_group" "dojo-shiro01-sg" {
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port = "80"
        to_port = "80"
        protocol = "tcp"
    }
    
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

output "web_server_instance_id" {
  value = aws_instance.dojo-shiro01-ec2.id
}

output "web_server_public_ip" {
  value = aws_instance.dojo-shiro01-ec2.public_ip
}

output "web_server_sg_id" {
  value = aws_security_group.dojo-shiro01-sg.id
}