module "vpn_access_server_aws" {
  source = "git@github.com:achuchulev/terraform-aws-openvpn-server.git"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"

  vpn_gw_subsidiary_network_cidr = "${var.subsidiary_networks}"

  cloudflare_email     = "${var.cloudflare_email}"
  cloudflare_token     = "${var.cloudflare_token}"
  cloudflare_zone      = "${var.cloudflare_zone}"
  cloudflare_subdomain = "${var.cloudflare_subdomain}"
}

module "vpn_gw_aws" {
  source = "git@github.com:achuchulev/terraform-aws-openvpn-gw.git"

  aws_access_key           = "${var.aws_access_key}"
  aws_secret_key           = "${var.aws_secret_key}"
  access_server_cidr_block = "${var.vpn_access_server_cidr}"
}

resource "null_resource" "vpn_profile" {
  triggers = {
    subsidiary_network = "${var.new_subsidiary_network}"
  }

  depends_on = ["module.vpn_access_server_aws", "module.vpn_gw_aws"]

  provisioner "remote-exec" {
    inline = [
      "sudo /usr/local/openvpn_as/scripts/sacli --key vpn.server.routing.private_network.${length(var.subsidiary_networks)+1} --value ${var.new_subsidiary_network}  ConfigPut",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} --key type --value user_compile UserPropPut",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} --new_pass ${var.openvpn_remote_client_passwd} SetLocalPassword",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} --key c2s_route.0 --value ${var.new_subsidiary_network} UserPropPut",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} --key prop_autologin --value true UserPropPut",
      "sleep 30",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} AutoGenerateOnBehalfOf",
      "sudo /usr/local/openvpn_as/scripts/sacli --user ${var.openvpn_remote_client_user} GetAutologin >${var.openvpn_remote_client_user}.ovpn",
      "sudo service openvpnas restart"
    ]

    connection {
      type        = "ssh"
      host        = "${module.vpn_access_server_aws.vpn_server_public_ip}"
      user        = "openvpnas"
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
    }
  }

  provisioner "local-exec" {
    command = "ssh-keyscan -H ${module.vpn_access_server_aws.vpn_server_public_ip} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = "ssh-keyscan -H ${module.vpn_gw_aws.vpn_gw_public_ip} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = "scp openvpnas@${module.vpn_access_server_aws.vpn_server_public_ip}:/home/openvpnas/${var.openvpn_remote_client_user}.ovpn /tmp/${var.openvpn_remote_client_user}.conf"
  }

  provisioner "local-exec" {
    command = "scp /tmp/${var.openvpn_remote_client_user}.conf ubuntu@${module.vpn_gw_aws.vpn_gw_public_ip}:/tmp/${var.openvpn_remote_client_user}.conf "
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/${var.openvpn_remote_client_user}.conf /etc/openvpn/",
      "sudo shutdown -r",
    ]

    connection {
      type        = "ssh"
      host        = "${module.vpn_gw_aws.vpn_gw_public_ip}"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
    }
  }
}
