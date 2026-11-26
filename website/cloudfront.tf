# AWS-managed policies only: the Free plan doesn't allow custom cache,
# origin request or response headers policies
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

# Everything from the viewer except Host: a function URL rejects a Host
# header that isn't its own
data "aws_cloudfront_origin_request_policy" "all_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = var.bucket_name
  description                       = "CloudFront signs every request to the site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "www_redirect" {
  name    = "matthomelab-www-redirect"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect www to the apex domain"
  publish = true
  code    = templatefile("${path.module}/functions/www-redirect.js", { domain = var.domain })
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = var.domain
  aliases             = [var.domain, "www.${var.domain}"]
  default_root_object = "index.html"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  web_acl_id          = aws_wafv2_web_acl.site.arn

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin {
    origin_id                = "lambda-counter"
    domain_name              = split("/", aws_lambda_function_url.counter.function_url)[2]
    origin_access_control_id = aws_cloudfront_origin_access_control.counter.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # The counter: never cached, GET only (OAC to a function URL can't sign
  # request bodies without a payload hash)
  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = "lambda-counter"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = false
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.www_redirect.arn
    }
  }

  # A missing object comes back from S3 as 403 (CloudFront can't list the
  # bucket), so both map to the 404 page
  dynamic "custom_error_response" {
    for_each = [403, 404]
    content {
      error_code            = custom_error_response.value
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 60
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
