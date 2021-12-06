
variable "location" {
  default = "westus2"
}

variable "user" {
  default = "lucaswindow"
}

variable "pass" {
  default = "Pass@123"
}

variable "vnets" {
  type    = list(string)
  default = ["10.0.0.0/16", "10.1.0.0/16"]
}

variable "subnets" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24", "10.1.0.0/24"]
}

variable "ports" {
  type    = list(number)
  default = [22, 80, 443, 8080, 8081, 9000]
}

