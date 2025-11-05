variable "project" { type = string }
variable "api_image" { type = string }
variable "worker_image" { type = string }
variable "api_cpu" { type = string, default = "512" }
variable "api_memory" { type = string, default = "1024" }
variable "worker_cpu" { type = string, default = "1024" }
variable "worker_memory" { type = string, default = "2048" }
variable "container_port" { type = number, default = 3000 }
variable "api_desired_count" { type = number, default = 2 }
variable "worker_desired_count" { type = number, default = 2 }
variable "worker_min" { type = number, default = 1 }
variable "worker_max" { type = number, default = 10 }
variable "sqs_scale_threshold" { type = number, default = 10 }

variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "ecs_security_group_id" { type = string }
variable "ecs_security_group_ids" { type = list(string) }
variable "sqs_queue_url" { type = string }
variable "sqs_arn" { type = string }
variable "s3_bucket" { type = string }
variable "s3_bucket_arn" { type = string }
variable "cloudfront_domain" { type = string }
variable "cloudfront_oac_iam_arn" { type = string }
variable "database_url" { type = string }
variable "secrets_arn" { type = string }
variable "api_keys" { type = string }
variable "acm_certificate_arn" { type = string }
variable "aws_region" { type = string, default = "us-east-1" }
