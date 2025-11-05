provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1" # CloudFront/ACM certs must be in us-east-1 for global distributions
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name      = "${var.project}-oac"
  description = "OAC for ${var.bucket}"
  signing_behavior = "always"
  signing_protocol = "sigv4"
  allowed_methods = ["GET","HEAD"]
  origin_request_protocol_policy = "https-only"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  is_ipv6_enabled = true
  default_cache_behavior {
    allowed_methods = ["GET","HEAD"]
    cached_methods  = ["GET","HEAD"]
    target_origin_id = "s3-${var.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    origin_request_policy_id = "88a5e8c7-f6b4-4e23-8e7b-3d3e4b1c9c9f" # CORS-friendly policy id (AWS managed)
    forwarded_values { query_string = false }
    min_ttl = 0
    default_ttl = 86400
    max_ttl = 31536000
  }

  origin {
    domain_name = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id   = "s3-${var.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_root_object = ""
  aliases = var.domain_names
}

resource "aws_s3_bucket" "images" {
  bucket = var.bucket
  acl    = "private"
}

output "domain_name" { value = aws_cloudfront_distribution.cdn.domain_name }
output "oac_iam_arn" { value = aws_cloudfront_origin_access_control.oac.iam_role_arn }
