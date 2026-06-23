variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the server (restrict to your IP)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 in the target region"
  type        = string
  # ap-southeast-1 Ubuntu 22.04 LTS — update per region
  default     = "ami-0df7a207adb9748c7"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "shopmonitor_db"
}

variable "db_user" {
  description = "MySQL application user"
  type        = string
  default     = "shopmonitor"
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for CloudWatch alerts (optional)"
  type        = string
  default     = ""
}
