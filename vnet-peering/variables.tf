
variable "location" {
  default = "brazilsouth"
}

variable "vnets" {
  type    = list(string)
  default = ["10.0.0.0/16", "10.1.0.0/16"]
}