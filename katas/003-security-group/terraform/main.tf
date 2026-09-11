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
    key = "katas/003-security-group/terraform.tfstate"
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
      Project = "003-security-group"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_instance" "dojo-003-ec2" {
  ami = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.dojo-003-sg.id]

  tags = {
    Name = "dojo-003-ec2"
  }
}

resource "aws_security_group" "dojo-003-sg" {
  description = "Only Allows Port 80"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "dojo-003-sg"
  }
}