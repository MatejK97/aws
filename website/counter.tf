# Visitor counter: CloudFront /api/* -> Lambda function URL -> DynamoDB.
# The function URL requires IAM auth and only this distribution may call it
# (Origin Access Control), so there is no public API endpoint to abuse.

# The boundary from the bootstrap stack, looked up by name
data "aws_iam_policy" "boundary" {
  name = "homelab-boundary"
}

# Provisioned at 1 RCU / 1 WCU: inside the always-free tier, and it can't
# scale up and bill more. Too many writes are throttled, not charged.
resource "aws_dynamodb_table" "visitors" {
  name           = "matthomelab-visitors"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Encrypted at rest with an AWS-owned key (the default, free); the table
  # holds one public number
}

resource "aws_cloudwatch_log_group" "counter" {
  name              = "/aws/lambda/matthomelab-visitor-counter"
  retention_in_days = 14
}

resource "aws_iam_role" "counter" {
  name                 = "matthomelab-visitor-counter"
  path                 = "/homelab/"
  permissions_boundary = data.aws_iam_policy.boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy" "counter" {
  name = "visitor-counter"
  role = aws_iam_role.counter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CountVisits"
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.visitors.arn
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.counter.arn}:*"
      },
    ]
  })
}

data "archive_file" "counter" {
  type        = "zip"
  source_file = "${path.module}/lambda/counter.py"
  output_path = "${path.module}/.build/counter.zip"
}

resource "aws_lambda_function" "counter" {
  function_name    = "matthomelab-visitor-counter"
  role             = aws_iam_role.counter.arn
  runtime          = "python3.13"
  handler          = "counter.handler"
  filename         = data.archive_file.counter.output_path
  source_code_hash = data.archive_file.counter.output_base64sha256
  memory_size      = 128
  timeout          = 5
  architectures    = ["arm64"]

  # -1 means no reservation. A small number caps how many copies can run at
  # once, but only if the account's concurrency quota leaves room for it.
  reserved_concurrent_executions = var.counter_reserved_concurrency

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitors.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.counter, aws_iam_role_policy.counter]
}

resource "aws_lambda_function_url" "counter" {
  function_name      = aws_lambda_function.counter.function_name
  authorization_type = "AWS_IAM"
}

# CloudFront needs both permissions to call a function URL through OAC, and
# only this distribution gets them
resource "aws_lambda_permission" "cloudfront_url" {
  statement_id           = "AllowCloudFrontFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.counter.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.site.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "cloudfront_invoke" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.site.arn
}

resource "aws_cloudfront_origin_access_control" "counter" {
  name                              = "matthomelab-visitor-counter"
  description                       = "CloudFront signs every request to the counter's function URL"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
