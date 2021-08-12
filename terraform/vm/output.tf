output "public_ips" {
  value = {
    for k, v in azurerm_public_ip.ama_sample_vm : k => v.ip_address
  }
}

output "private_ips" {
  value = {
    for k, v in azurerm_network_interface.ama_sample_vm : k => v.private_ip_address
  }
}
