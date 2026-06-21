terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "shopmonitor-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "shopmonitor-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "shopmonitor"
      ManagedBy = "terraform"
      Env       = var.environment
    }
  }
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security group ---
resource "aws_security_group" "shopmonitor" {
  name        = "shopmonitor-sg"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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

# --- IAM role for EC2 (CloudWatch access) ---
resource "aws_iam_role" "shopmonitor_ec2" {
  name = "shopmonitor-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.shopmonitor_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "shopmonitor" {
  name = "shopmonitor-instance-profile"
  role = aws_iam_role.shopmonitor_ec2.name
}

# --- EC2 instance ---
resource "aws_instance" "shopmonitor" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.shopmonitor.id]
  iam_instance_profile   = aws_iam_instance_profile.shopmonitor.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    db_name   = var.db_name
    db_user   = var.db_user
  }))
}

# --- CloudWatch CPU alarm ---
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "shopmonitor-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU above 80% for 10 minutes"

  dimensions = {
    InstanceId = aws_instance.shopmonitor.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
}
