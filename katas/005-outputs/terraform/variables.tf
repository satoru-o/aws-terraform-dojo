variable "ami" {
  type = string
  description = "ami id"
  default = "ami-053ea429a1c73a5b7"
}

variable "instance_type" {
  type = string
  description = "EC2 Instance Type"
  default = "t2.nano"
}