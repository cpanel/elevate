output "address" {
  value = openstack_compute_instance_v2.elevatevm.access_ip_v4
}

output "ssh_port" {
  value = openstack_compute_instance_v2.elevatevm.port
}

output "id" {
  value = openstack_compute_instance_v2.elevatevm.id
}