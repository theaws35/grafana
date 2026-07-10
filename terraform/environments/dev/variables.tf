variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ami_id" {
  type        = string
  description = "Amazon Linux 2023 AMI in the target region"
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}

variable "prometheus_ebs_size_gb" {
  type    = number
  default = 100
}
