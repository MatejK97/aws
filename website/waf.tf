# WAF web ACL, required by the CloudFront flat-rate plan (the Free plan
# includes 5 rules). Requests it blocks don't count toward the plan's
# allowance, and the plan has no overage charges either way.
resource "aws_wafv2_web_acl" "site" {
  provider = aws.us_east_1

  name        = "matthomelab-website"
  description = "matthomelab.xyz: IP reputation, common threats, rate limit"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Addresses AWS threat intelligence knows as malicious (bots, scanners)
  rule {
    name     = "aws-ip-reputation"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Common exploit patterns (OWASP-style)
  rule {
    name     = "aws-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common"
      sampled_requests_enabled   = true
    }
  }

  # Known-bad request patterns, such as Log4j probes
  rule {
    name     = "aws-known-bad-inputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # A person reading a one-page site never gets near this; a scraper does.
  # The fifth rule is kept free for a stricter limit on /api/* (visitor counter).
  rule {
    name     = "rate-limit-per-ip"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.rate_limit
        evaluation_window_sec = 300
        aggregate_key_type    = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "matthomelab-website"
    sampled_requests_enabled   = true
  }
}
