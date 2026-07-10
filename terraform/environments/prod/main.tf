terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "grafana" {
  source = "../../modules/grafana"

  name_prefix         = "${var.environment}-monitoring"
  vpc_id              = var.vpc_id
  subnet_id           = var.subnet_id
  key_name            = var.key_name
  ami_id              = var.ami_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "prometheus" {
  source = "../../modules/prometheus"

  name_prefix         = "${var.environment}-monitoring"
  vpc_id              = var.vpc_id
  subnet_id           = var.subnet_id
  key_name            = var.key_name
  ami_id              = var.ami_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ebs_volume_size_gb  = var.prometheus_ebs_size_gb
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
