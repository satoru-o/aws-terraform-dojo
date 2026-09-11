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
    key = "katas/001-provider-init/terraform.tfstate"
    region = "ap-northeast-1"
    use_lockfile = true
    encrypt = true
    profile = "aws-terraform-dojo"
  }
}