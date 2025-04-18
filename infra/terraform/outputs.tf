output "ResourceGroupName" {
  value = data.azurerm_resource_group.rg.name
}

output "AzureRegion" {
  value = data.azurerm_resource_group.rg.location
}

output "BastionName" {
  value = module.azure_bastion.name
}

output "vm_private_ips" {
  description = "PrivateIP addresses of the VMs"
  value = [
    for vm in module.webappServers : vm.network_interfaces.nic0.private_ip_address
  ]
}

output "lb_public_ip" {
  value = azurerm_public_ip.webapp_lb_pip.ip_address
}

output "vm_resourceId" {
  value = [
    for vm in module.webappServers : vm.resource_id
  ]
} 