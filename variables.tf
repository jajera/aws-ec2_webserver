variable "resource_tags" {
  description = "Resource tag identification."
  nullable    = false
  default = {
    email    = "jdcajera@gmail.com"
    owner    = "John Ajera"
    use_case = "webserver"
  }
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
  nullable    = false
  default     = "RG-webserver"
}

variable "aws_availability_zone" {
  description = "AWS availability zone name."
  type        = string
  nullable    = false
  default     = "ap-southeast-1c"
}

variable "private_ip" {
  description = "Private IP."
  type        = string
  nullable    = false
  default     = "172.16.10.12"
}

variable "vpc_cidr" {
  description = "Virtual private cloud CIDR."
  type        = string
  nullable    = false
  default     = "172.16.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR."
  type        = string
  nullable    = false
  default     = "172.16.10.0/24"
}
