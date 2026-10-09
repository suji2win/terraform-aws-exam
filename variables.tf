variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ca-central-1"
}

variable "my_ip_cidr" {
  description = "Your public IPv4 address with /32 for SSH access"
  type        = string
}

variable "public_key_path" {
  description = "Location of your SSH public key"
  type        = string
  default     = "C:/Users/Sujit/.ssh/terraform-exam-key.pub"
}