resource "random_password" "db" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.project}-db-secret"
}

resource "aws_secretsmanager_secret_version" "db_version" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
  })
}

resource "aws_db_subnet_group" "db_subnet" {
  name       = "${var.project}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags = { Name = "${var.project}-db-subnet" }
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.project}-postgres"
  engine                  = "postgres"
  engine_version          = "15.3"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  username                = var.db_username
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.db_subnet.name
  skip_final_snapshot     = var.skip_final_snapshot
  publicly_accessible     = false
  multi_az                = true
  vpc_security_group_ids  = var.security_group_ids
  tags = { Name = "${var.project}-postgres" }
}

output "endpoint" { value = aws_db_instance.postgres.address }
output "port" { value = aws_db_instance.postgres.port }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
