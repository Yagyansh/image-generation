resource "aws_sqs_queue" "dlq" {
  name = "${var.name}-dlq"
}

resource "aws_sqs_queue" "queue" {
  name = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = { Name = var.name }
}

output "sqs_url" { value = aws_sqs_queue.queue.id }
output "sqs_arn" { value = aws_sqs_queue.queue.arn }
