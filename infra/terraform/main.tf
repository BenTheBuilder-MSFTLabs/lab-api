## Import Core Modules   
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source                    = "Azure/avm-utl-regions/azurerm"
  version                   = "0.3.0"
  enable_telemetry          = true
  availability_zones_filter = true
}

module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"
  location      = data.azurerm_resource_group.rg.location
  cache_results = false
  vm_filters = {
    max_vcpus = 2
    
  }
}

# Create Virtual Network
module "virtual_network" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm"

  address_space       = ["10.0.0.0/24"]
  location            = data.azurerm_resource_group.rg.location
  name                = "vnet-${var.initials}${var.random_string}"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.resourceTags
  subnets = {
    "subnet1" = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.0.0/26"]
    }
    "subnet2" = {
      name             = "AppSubnet"
      address_prefixes = ["10.0.0.64/26"]
    }
  }
}

# Create a Network Security Group
resource "azurerm_network_security_group" "app_subnet_nsg" {
  name                = "AppSubnetNSG"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.0.0/24"
  }

  tags = local.resourceTags
}

# Associate the NSG with the AppSubnet
resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_association" {
  subnet_id                 = module.virtual_network.subnets["subnet2"].resource_id  
  network_security_group_id = azurerm_network_security_group.app_subnet_nsg.id
}

# Create Azure Bastion Host
module "azure_bastion" {
  source = "Azure/avm-res-network-bastionhost/azurerm"

  enable_telemetry    = false
  name                = "bastion_${var.initials}${var.random_string}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  copy_paste_enabled  = true
  file_copy_enabled   = true
  sku                 = "Standard"
  ip_connect_enabled     = true
  shareable_link_enabled = true
  tunneling_enabled      = true
  kerberos_enabled       = true
  ip_configuration = {
    name                 = "my-ipconfig"
    subnet_id            = module.virtual_network.subnets["subnet1"].resource_id
    create_public_ip     = true
    public_ip_address_name = "bastionpip-${var.initials}${var.random_string}"
  }
  tags = local.resourceTags
}


# Create Azure Public IP for LoadBalancer
resource "azurerm_public_ip" "webapp_lb_pip" {
  name                = "lbpip${var.initials}${var.random_string}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = local.resourceTags
}

# Create Azure Load Balancer
resource "azurerm_lb" "webapp_lb" {
  name                = "lb-${var.initials}${var.random_string}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

frontend_ip_configuration {
    name                 = "frontend-${var.initials}${var.random_string}"
    public_ip_address_id = azurerm_public_ip.webapp_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "webapp_backend_pool" {
  loadbalancer_id = azurerm_lb.webapp_lb.id
  name            = "test-pool"
}

resource "azurerm_lb_probe" "webapp_http_probe" {
  loadbalancer_id = azurerm_lb.webapp_lb.id
  name            = "test-probe"
  port            = 80
}

# Create Load Balancer Rule
# This rule will forward traffic from the frontend IP configuration to the backend address pool
# on port 80 using TCP protocol. It also disables outbound SNAT for the backend pool.
# The probe is used to check the health of the backend instances.
resource "azurerm_lb_rule" "example_rule" {
  loadbalancer_id                = azurerm_lb.webapp_lb.id
  name                           = "test-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  disable_outbound_snat          = true
  frontend_ip_configuration_name = "frontend-${var.initials}${var.random_string}"
  probe_id                       = azurerm_lb_probe.webapp_http_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.webapp_backend_pool.id]
}


resource "azurerm_lb_outbound_rule" "example" {
  name                    = "web-outbound"
  loadbalancer_id         = azurerm_lb.webapp_lb.id
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.webapp_backend_pool.id
  frontend_ip_configuration {
    name = "frontend-${var.initials}${var.random_string}"
  }
}


# Create WebApp Servers
module "webappServers" {
    source = "Azure/avm-res-compute-virtualmachine/azurerm"
    version = "~>0.17.0"
    enable_telemetry = true
    count = var.appServersConfig.vmcount
    resource_group_name = data.azurerm_resource_group.rg.name
    name = "${var.appServersConfig.vmnameprefix}${count.index}" # Unique name per instance
    location = data.azurerm_resource_group.rg.location
    encryption_at_host_enabled = false
    generate_admin_password_or_ssh_key = false
    os_type = "Linux"
    sku_size = var.appServersConfig.vm_sku
    zone = var.appServersConfig.zones[0]
    tags = local.resourceTags
    admin_username = var.appServersConfig.adminUsername
    admin_ssh_keys = [
        {
        public_key = file(var.appServersConfig.key_path)
        username   = var.appServersConfig.adminUsername
        }
    ]
    source_image_reference = {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-focal"
        sku       = "20_04-lts-gen2"
        version   = "latest"
    }
    network_interfaces = {
        nic0 = {
            name = "${var.appServersConfig.vmnameprefix}${count.index}-nic0"
            ip_configurations = {
                ipconfig0 = {
                    name = "ipconfig1"
                    private_ip_address_allocation = "Dynamic"
                    private_ip_subnet_resource_id = module.virtual_network.subnets["subnet2"].resource_id
                    create_public_ip_address = false
                }
            }
        }
    }
}

# Associate Network Interface to the Backend Pool of the Load Balancer
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count                   = var.appServersConfig.vmcount
  network_interface_id    = module.webappServers[count.index].network_interfaces["nic0"].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.webapp_backend_pool.id
}