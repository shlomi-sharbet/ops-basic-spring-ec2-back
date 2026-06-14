
# 1. Create Hosted Zone in Route53
resource "aws_route53_zone" "main" {
  name = "shlomi.com"
}

# 2. Create A Record for API Raw (Simulated back-end API)
resource "aws_route53_record" "ec2_raw" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api-raw.shlomi.com"
  type    = "A"
  ttl     = 300
  records = ["172.17.0.1"]
}


# 4. ACM Certificate (Optional/Mock - CloudFront requires us-east-1 cert)
resource "aws_acm_certificate" "cert" {
  domain_name       = "shlomi.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.shlomi.com"
  ]
}

# 5. CloudFront Distribution (Pointing to S3 and EC2-raw)
# (Note: LocalStack Community version ignores some advanced distribution features, but the infrastructure will be created cleanly!)
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["ec2-stage.shlomi.com"]

  # Origin 1: S3 Frontend (pointing to the bucket defined in s3.tf)
  origin {
    domain_name = aws_s3_bucket.static_bucket.bucket_regional_domain_name
    origin_id   = "S3-frontend"
  }

  # Origin 2: API Backend (EC2 Raw)
  origin {
    domain_name = "${aws_route53_record.ec2_raw.name}:8080"
    origin_id   = "EC2-backend"

    custom_origin_config {
      http_port              = 8080
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default Behavior -> Route to S3 Frontend
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "allow-all"
  }

  # API Behavior -> Route to Backend
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EC2-backend"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "allow-all"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# 6. CNAME Record pointing to CloudFront
resource "aws_route53_record" "cdn_cname" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "ec2-stage.shlomi.com"
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.cdn.domain_name]
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "The domain name of the CloudFront distribution"
}
