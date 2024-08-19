variable "user" {
  type    = string
  default = "resu"
}

variable "application_credential_id" {
  type = string
}

variable "application_credential_secret" {
  type = string
}

variable "os_password" {
  type = string
}

variable "os_auth_region" {
  type = string
}

variable "os_auth_url" {
  type = string
}

variable "os_project_domain_name" {
  type = string
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key matching the public key added to the VMs /root/.ssh/authorized_keys file to allow user access."
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key matching the public key added to the VMs /root/.ssh/authorized_keys file to allow user access."
  sensitive   = true
}

variable "image_name" {
  type    = string
  default = "11.110.0.* on CentOS 7"
}

variable "cpanel_release_version" {
  type    = string
  default = "110"
}

variable "flavor_name" {
  type    = string
  default = "c2.d20.r2048"
}