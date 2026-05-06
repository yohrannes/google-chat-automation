variable "aws_region" {
  description = "The AWS region where resources are deployed."
  type        = string
  default     = "sa-east-1"
}

variable "aws_profile" {
  description = "The AWS profile to use for authentication."
  type        = string
  default     = "terraform"
}

variable "function_name" {
  description = "The name of the Lambda function."
  type        = string
  default     = "coleta-uptimerobot"
}