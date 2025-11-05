data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" ; identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "task_role" {
  name               = "${var.project}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role" "exec_role" {
  name = "${var.project}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "worker_policy" {
  name = "${var.project}-worker-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [ "sqs:ReceiveMessage","sqs:DeleteMessage","sqs:GetQueueAttributes","sqs:ChangeMessageVisibility" ], Resource = var.sqs_arn },
      { Effect = "Allow", Action = [ "s3:PutObject","s3:PutObjectAcl","s3:GetObject" ], Resource = ["${var.s3_bucket_arn}/*"] },
      { Effect = "Allow", Action = [ "secretsmanager:GetSecretValue" ], Resource = var.secrets_arn },
      { Effect = "Allow", Action = [ "logs:CreateLogStream","logs:PutLogEvents" ], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_attach" {
  role = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.worker_policy.arn
}

resource "aws_ecs_cluster" "cluster" { name = "${var.project}-cluster" }

resource "aws_cloudwatch_log_group" "api" {
  name = "/ecs/${var.project}/api"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "/ecs/${var.project}/worker"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "api_task" {
  family                   = "${var.project}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.exec_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([{
    name = "api",
    image = var.api_image,
    portMappings = [{ containerPort = var.container_port }],
    environment = [
      { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
      { name = "IMAGE_S3_BUCKET", value = var.s3_bucket },
      { name = "CLOUDFRONT_URL", value = var.cloudfront_domain },
      { name = "DATABASE_URL", value = var.database_url },
      { name = "API_KEYS", value = var.api_keys }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group" = aws_cloudwatch_log_group.api.name,
        "awslogs-region" = var.aws_region,
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "worker_task" {
  family                   = "${var.project}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.exec_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([{
    name = "worker",
    image = var.worker_image,
    environment = [
      { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
      { name = "IMAGE_S3_BUCKET", value = var.s3_bucket },
      { name = "CLOUDFRONT_URL", value = var.cloudfront_domain },
      { name = "DATABASE_URL", value = var.database_url }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group" = aws_cloudwatch_log_group.worker.name,
        "awslogs-region" = var.aws_region,
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])
}

# ALB
resource "aws_lb" "alb" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.project}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ECS Services
resource "aws_ecs_service" "api" {
  name            = "${var.project}-api"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "api"
    container_port   = var.container_port
  }
  depends_on = [aws_lb_listener.https]
}

resource "aws_ecs_service" "worker" {
  name            = "${var.project}-worker"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.worker_task.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
    assign_public_ip = false
  }
}

resource "aws_appautoscaling_target" "worker_target" {
  max_capacity       = var.worker_max
  min_capacity       = var.worker_min
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_cloudwatch_metric_alarm" "sqs_alarm" {
  alarm_name = "${var.project}-sqs-depth-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = 60
  threshold   = var.sqs_scale_threshold
  dimensions = { QueueName = element(split("/", var.sqs_queue_url), length(split("/", var.sqs_queue_url)) - 1) }
  alarm_actions = [aws_appautoscaling_target.worker_target.arn]
}

output "alb_dns" { value = aws_lb.alb.dns_name }
