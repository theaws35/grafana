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
  description = "Prefix for Grafana resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC where Grafana will run"
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the Grafana instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for Grafana host"
  default     = "t3.small"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach Grafana UI (port 3000)"
  default     = ["10.0.0.0/8"]
}

variable "ami_id" {
  type        = string
  description = "AMI ID (Amazon Linux 2 or AL2023)"
}

variable "grafana_port" {
  type    = number
  default = 3000
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}

resource "aws_security_group" "grafana" {
  name        = "${var.name_prefix}-grafana-sg"
  description = "Grafana UI and SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana UI"
    from_port   = var.grafana_port
    to_port     = var.grafana_port
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
    Name = "${var.name_prefix}-grafana-sg"
  })
}

resource "aws_instance" "grafana" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.grafana.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-grafana"
    Role = "grafana"
  })
}

output "grafana_instance_id" {
  value = aws_instance.grafana.id
}

output "grafana_private_ip" {
  value = aws_instance.grafana.private_ip
}

output "grafana_security_group_id" {
  value = aws_security_group.grafana.id
}
