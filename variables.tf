variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}
variable "instance_type" {
  description = "The type of EC2 instance to deploy."
  type        = string
  default     = "t2.2xlarge"
}
