# Only the records this site needs. Everything else in the zone (*.home,
# send, the n8n webhook) stays managed by hand and untouched.
data "cloudflare_zone" "site" {
  filter = {
    name = var.domain
  }
}

# DNS only (not proxied): CloudFront serves the site and terminates TLS.
# Cloudflare flattens the CNAME at the apex, so the bare domain works.
resource "cloudflare_dns_record" "site" {
  for_each = toset([var.domain, "www.${var.domain}"])

  zone_id = data.cloudflare_zone.site.id
  name    = each.value
  type    = "CNAME"
  content = aws_cloudfront_distribution.site.domain_name
  ttl     = 1
  proxied = false
  comment = "CloudFront; managed by Terraform (homelab/aws)"
}
