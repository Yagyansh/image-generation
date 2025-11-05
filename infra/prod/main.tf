terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
  required_version = ">= 1.3.0"
}

provider "aws" { region = var.aws_region }

module "vpc" {
  source = "../modules/vpc"
  project = var.project
  aws_region = var.aws_region
  vpc_cidr = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones = var.availability_zones
}

module "ecr" {
  source = "../modules/ecr"
  repo_name = var.ecr_repo_name
}

module "cloudfront" {
  source = "../modules/cloudfront"
  bucket = var.s3_bucket_name
  domain_names = var.cloudfront_domains
  project = var.project
  providers = { aws = aws.us_east_1 }
}

module "s3" {
  source = "../modules/s3"
  bucket = var.s3_bucket_name
  cloudfront_oac_iam_arn = module.cloudfront.oac_iam_arn
}

module "sqs" {
  source = "../modules/sqs"
  name = var.sqs_name
}

resource "aws_security_group" "alb_sg" {
  name   = "${var.project}-alb-sg"
  vpc_id = module.vpc.vpc_id
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
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "ecs_sg" {
  name   = "${var.project}-ecs-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = var.container_port; to_port = var.container_port; protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

module "rds" {
  source = "../modules/rds"
  project = var.project
  private_subnet_ids = module.vpc.private_subnet_ids
  db_username = var.db_username
  instance_class = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  security_group_ids = [aws_security_group.ecs_sg.id]
  skip_final_snapshot = true
}

module "ecs" {
  source = "../modules/ecs"
  project = var.project
  api_image = "${module.ecr.repository_url}:latest"
  worker_image = "${module.ecr.repository_url}:latest"
  api_cpu = var.api_cpu
  api_memory = var.api_memory
  worker_cpu = var.worker_cpu
  worker_memory = var.worker_memory
  container_port = var.container_port
  api_desired_count = var.api_desired_count
  worker_desired_count = var.worker_desired_count
  worker_min = var.worker_min
  worker_max = var.worker_max
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_security_group_id = aws_security_group.alb_sg.id
  ecs_security_group_id = aws_security_group.ecs_sg.id
  api_keys = var.api_keys
  sqs_queue_url = module.sqs.sqs_url
  sqs_arn = module.sqs.sqs_arn
  s3_bucket = module.s3.bucket
  s3_bucket_arn = "arn:aws:s3:::${module.s3.bucket}"
  cloudfront_domain = module.cloudfront.domain_name
  database_url = "postgresql://${var.db_username}:${random_password_placeholder}/${module.rds.endpoint}:${module.rds.port}/postgres"
  secrets_arn = module.rds.secret_arn
  acm_certificate_arn = var.acm_certificate_arn
  aws_region = var.aws_region
}


data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = module.rds.secret_arn
}

output "alb_dns" { value = module.ecs.alb_dns }
output "cloudfront_domain" { value = module.cloudfront.domain_name }
output "s3_bucket" { value = module.s3.bucket }
output "sqs_url" { value = module.sqs.sqs_url }
output "ecr_repo" { value = module.ecr.repository_url }
output "rds_endpoint" { value = module.rds.endpoint }
