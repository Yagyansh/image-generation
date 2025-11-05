variable "project" { type = string }
variable "aws_region" { type = string }
variable "vpc_cidr" { type = string, default = "10.0.0.0/16" }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
