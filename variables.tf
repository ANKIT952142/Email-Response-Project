variable "sender_email" {
  description = "Verified SES email address for sending"
  type        = string
}

variable "recipient_email" {
  description = "Email that receives the Accept/Reject decision links"
  type        = string
}

variable "ses_receiver_email" {
  description = "SES-monitored email address for receiving decisions"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
