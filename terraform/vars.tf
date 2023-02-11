variable "region" {
  description = "The AWS Region"
  type        = string
  default     = "us-east-2"
}


variable "lambda_name" {
  description = "The prefix of the lambda"
  type        = string
  default     = ""
}