variable "cloudflare_zone" {}

variable "cloudflare_subdomain" {}

variable "cloudflare_email" {}

variable "cloudflare_token" {}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "openvpn_remote_client_user" {}

variable "openvpn_remote_client_passwd" {}

variable "vpn_access_server_cidr" {}

variable "subsidiary_networks" {
  type = "list"
}

variable "new_subsidiary_network" {}
