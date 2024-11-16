# outputs.tf

output "s3_bucket_name" {
  description = "S3 bucket name for storing emails"
  value       = aws_s3_bucket.ses_email_bucket.bucket
}

output "send_email_lambda_arn" {
  description = "ARN of the Lambda function for sending emails"
  value       = aws_lambda_function.send_email_function.arn
}

output "process_email_lambda_arn" {
  description = "ARN of the Lambda function for processing emails"
  value       = aws_lambda_function.process_email_function.arn
}
