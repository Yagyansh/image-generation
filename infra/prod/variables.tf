variable "aws_region" { type = string, default = "us-east-1" }
variable "project" { type = string, default = "chronicle-image-api" }
variable "vpc_cidr" { type = string, default = "10.0.0.0/16" }
variable "availability_zones" { type = list(string), default = ["us-east-1a","us-east-1b","us-east-1c"] }

variable "public_subnet_cidrs" { type = list(string), default = ["10.0.0.0/24","10.0.1.0/24","10.0.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string), default = ["10.0.100.0/24","10.0.101.0/24","10.0.102.0/24"] }

variable "ecr_repo_name" { type = string, default = "chronicle-image-api" }
variable "s3_bucket_name" { type = string, default = "chronicle-image-api-images-${random_id.suffix.hex}" }
variable "sqs_name" { type = string, default = "chronicle-image-jobs" }
variable "s3_bucket_region" { type = string, default = "us-east-1" }

variable "db_username" { type = string, default = "chronicle" }
variable "db_instance_class" { type = string, default = "db.t3.medium" }
variable "db_allocated_storage" { type = number, default = 20 }

variable "api_cpu" { type = string, default = "512" }
variable "api_memory" { type = string, default = "1024" }
variable "worker_cpu" { type = string, default = "1024" }
variable "worker_memory" { type = string, default = "2048" }

variable "container_port" { type = number, default = 3000 }
variable "api_desired_count" { type = number, default = 2 }
variable "worker_desired_count" { type = number, default = 2 }
variable "worker_min" { type = number, default = 1 }
variable "worker_max" { type = number, default = 10 }

variable "api_keys" { type = string }

# Manual Input after creation of ACM
variable "acm_certificate_arn" { type = string }

variable "cloudfront_domains" { type = list(string), default = [] }
