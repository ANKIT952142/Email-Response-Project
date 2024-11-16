terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.region
}

# S3 Bucket for SES
resource "aws_s3_bucket" "ses_email_bucket" {
  bucket        = "ses-email-processing-bucket"
  force_destroy = true  # Allows deletion of non-empty bucket during destroy
}

# S3 Bucket Policy with Full Permissions for SES
resource "aws_s3_bucket_policy" "ses_email_bucket_policy" {
  bucket = aws_s3_bucket.ses_email_bucket.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ses.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.ses_email_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Get current account ID dynamically
data "aws_caller_identity" "current" {}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "default-rule-set"
}

# Activate SES Rule Set
resource "aws_ses_active_receipt_rule_set" "activate_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
}

# SES Receipt Rule to Add Header and Store in S3
resource "aws_ses_receipt_rule" "store" {
  depends_on = [aws_s3_bucket_policy.ses_email_bucket_policy] # Explicit dependency
  
  name          = "email-to-s3-rule"
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  recipients    = [var.ses_receiver_email]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.ses_email_bucket.bucket
    position          = 1
    object_key_prefix = "emails/"  # Prefix for S3 objects
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_ses_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

# IAM Policy for Lambda Execution
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_ses_policy"
  description = "Policy for Lambda to interact with SES and S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["ses:SendEmail", "ses:SendRawEmail"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["s3:GetObject", "s3:PutObject"],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.ses_email_bucket.arn}/*"
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
}

# Attach IAM Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Archive Lambda1.py (Send Email Lambda)
data "archive_file" "lambda1_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda1.py"
  output_path = "${path.module}/send_email.zip"
}

# Archive Lambda2.py (Process Email Lambda)
data "archive_file" "lambda2_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda2.py"
  output_path = "${path.module}/process_email.zip"
}

# Lambda Function 1: Send Email
resource "aws_lambda_function" "send_email_function" {
  function_name = "send-email-function"
  handler       = "lambda1.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda1_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda1_zip.output_path)

  environment {
    variables = {
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
      SES_RECEIVER_EMAIL = var.ses_receiver_email
    }
  }
}

# Lambda Function 2: Process Email from S3
resource "aws_lambda_function" "process_email_function" {
  function_name = "process-email-function"
  handler       = "lambda2.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda2_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda2_zip.output_path)

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.ses_email_bucket.bucket
    }
  }
}

# S3 Bucket Notification to Trigger Lambda
resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = aws_s3_bucket.ses_email_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_email_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "emails/"
  }
}

# Grant S3 Permission to Invoke Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_email_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ses_email_bucket.arn
}

