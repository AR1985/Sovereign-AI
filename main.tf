terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "g6.xlarge" # 1x L4, 24 GB GPU memory
}

variable "model" {
  default = "Qwen/Qwen3-8B" # ungated, so no Hugging Face token needed
}

provider "aws" {
  region = var.region
}

# AWS-maintained image with NVIDIA drivers, Docker and nvidia-container-toolkit preinstalled
data "aws_ssm_parameter" "dlami" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-22.04/latest/ami-id"
}

# shortcut: default VPC with a public IP for outbound downloads, move to a private subnet + NAT if this becomes shared
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "llm" {
  name   = "llm-host"
  vpc_id = data.aws_vpc.default.id

  # no ingress: access is only through SSM port forwarding
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "llm" {
  name = "llm-host"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.llm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "llm" {
  name = "llm-host"
  role = aws_iam_role.llm.name
}

resource "aws_instance" "llm" {
  ami                    = data.aws_ssm_parameter.dlami.value
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.llm.name
  vpc_security_group_ids = [aws_security_group.llm.id]

  root_block_device {
    volume_size = 100 # vLLM image (~10 GB) + model weights (~16 GB) + headroom
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    docker run -d --restart unless-stopped --gpus all --ipc=host \
      -p 127.0.0.1:8000:8000 \
      -v /opt/hf-cache:/root/.cache/huggingface \
      vllm/vllm-openai:latest \
      --model ${var.model} --max-model-len 8192
  EOF

  tags = { Name = "llm-host" }
}

output "instance_id" {
  value = aws_instance.llm.id
}

output "port_forward_command" {
  value = "aws ssm start-session --region ${var.region} --target ${aws_instance.llm.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8000,localPortNumber=8000"
}
