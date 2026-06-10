# Optional Terraform version of the same infrastructure (not used in final demo).
# AWS CLI scripts in scripts/ were used instead because Terraform provider download failed on lab network.
# Ref: https://developer.hashicorp.com/terraform/docs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "ssh_cidr" {
  description = "Your public IPv4, e.g. 203.0.113.10/32"
  type        = string
}

# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "projectp2" {
  name        = "ProjectP2"
  description = "For part 2"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "minecraft" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  key_name               = "ProjectP2"
  vpc_security_group_ids = [aws_security_group.projectp2.id]

  tags = {
    Name = "Project part 2"
  }
}

output "public_ip" {
  value = aws_instance.minecraft.public_ip
}
