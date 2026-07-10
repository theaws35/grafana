terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "name_prefix" {
  type        = string
  description = "Prefix for Prometheus resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC where Prometheus will run"
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the Prometheus instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for Prometheus host"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach Prometheus (port 9090) and SSH"
  default     = ["10.0.0.0/8"]
}

variable "ami_id" {
  type        = string
  description = "AMI ID (Amazon Linux 2 or AL2023)"
}

variable "prometheus_port" {
  type    = number
  default = 9090
}

variable "ebs_volume_size_gb" {
  type        = number
  description = "Root/data volume size for Prometheus TSDB"
  default     = 100
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}

resource "aws_security_group" "prometheus" {
  name        = "${var.name_prefix}-prometheus-sg"
  description = "Prometheus API and SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "Prometheus API"
    from_port   = var.prometheus_port
    to_port     = var.prometheus_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-prometheus-sg"
  })
}

resource "aws_instance" "prometheus" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.prometheus.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = var.ebs_volume_size_gb
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-prometheus"
    Role = "prometheus"
  })
}

output "prometheus_instance_id" {
  value = aws_instance.prometheus.id
}

output "prometheus_private_ip" {
  value = aws_instance.prometheus.private_ip
}

output "prometheus_security_group_id" {
  value = aws_security_group.prometheus.id
}
