# Define required providers
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  user_name                     = var.user
  application_credential_id     = var.application_credential_id
  application_credential_secret = var.application_credential_secret
  auth_url                      = var.os_auth_url
  region                        = var.os_auth_region
}

data "openstack_images_image_ids_v2" "images" {
  name_regex = var.image_name
  sort       = "updated_at"
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = file("${path.root}/cloud-config.yaml")
  }
}

resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "random_string" "keyname" {
  length  = 22
  special = false
}

resource "openstack_compute_keypair_v2" "tf_remote_key" {
  name   = "${random_string.keyname.result}-deletethis"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "openstack_compute_instance_v2" "elevatevm" {
  name        = "elevate.github.cpanel.net"
  image_id    = sort(data.openstack_images_image_ids_v2.images.ids)[0]
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.tf_remote_key.name
  user_data = "${data.template_cloudinit_config.config.rendered}"
  network {
    name = "hou-prod-external"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      echo "START_REMOTE_EXEC"
      touch /root/.ssh/id_ed25519
      chmod 600 /root/.ssh/id_ed25519
      echo "${var.ssh_access_key}" >> /root/.ssh/id_ed25519
      echo 'waiting on cloud-init...'
      cloud-init status --wait > /dev/null || true
    EOF
    ]
    connection {
        type        = "ssh"
        host        = self.access_ip_v4
        user        = "root"
        script_path = "/root/elevate_bootstrap"
        private_key = tls_private_key.ssh.private_key_pem
    }
  }
}

