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
    key = "katas/002-ec2-only/terraform.tfstate"
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
      Project = "002-ec2-only"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_instance" "dojo-shiro-ec2" {
  ami = var.ami
  instance_type = var.instance_type

  tags = {
    Name = "dojo-shiro-ec2"
  }
}