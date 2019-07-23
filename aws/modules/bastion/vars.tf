variable "vpc_id" {
  description = "The id of the main vpc"
}

variable "public_subnet_id" {
  description = "The id of the public subnet in the vpc"
}

variable "key_name" {
  description = "The name of the key to attach to the bastion instance"
}

variable "local_ip" {
  description = "The local IP address that is allowed to connect to the bastion"
}
