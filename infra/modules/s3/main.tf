resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket ${var.bucket}"
  deletion_window_in_days = 30
  tags = { Name = "${var.bucket}-kms" }
}

resource "aws_s3_bucket" "images" {
  bucket = var.bucket
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
        kms_master_key_id = aws_kms_key.s3.arn
      }
    }
  }

  versioning { enabled = true }
  lifecycle_rule {
    id      = "expire-temp"
    enabled = true
    expiration { days = 365 }
  }
  force_destroy = false
  tags = { Name = var.bucket }
}

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"
    principals {
      type = "AWS"
      identifiers = [var.cloudfront_oac_iam_arn]
    }
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.images.arn}/*"]
  }
}

output "bucket" { value = aws_s3_bucket.images.bucket }
output "kms_key_arn" { value = aws_kms_key.s3.arn }
