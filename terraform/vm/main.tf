terraform {
  required_version = "~> 1.0.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.72"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ama_sample_vm" {
  name     = local.ama_sample_vm_rg
  location = local.ama_sample_vm_location
}

resource "azurerm_virtual_network" "vnet_default" {
  name                = "vnet-default"
  resource_group_name = azurerm_resource_group.ama_sample_vm.name
  location            = azurerm_resource_group.ama_sample_vm.location
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.ama_sample_vm.name
  virtual_network_name = azurerm_virtual_network.vnet_default.name
  address_prefixes     = ["10.0.0.0/16"]
}

resource "azurerm_public_ip" "ama_sample_vm" {
  count               = local.vm_count
  name                = "pip-ama-sample-${count.index}"
  location            = azurerm_resource_group.ama_sample_vm.location
  resource_group_name = azurerm_resource_group.ama_sample_vm.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "ama_sample_vm" {
  count               = local.vm_count
  name                = "nic-ama-sample-${count.index}"
  location            = azurerm_resource_group.ama_sample_vm.location
  resource_group_name = azurerm_resource_group.ama_sample_vm.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ama_sample_vm[count.index].id
  }
}

resource "azurerm_network_security_group" "ssh" {
  # Workaround https://github.com/hashicorp/terraform/issues/24663
  depends_on = [
    azurerm_network_interface.ama_sample_vm,
  ]
  name                = "nsg-ssh"
  location            = azurerm_resource_group.ama_sample_vm.location
  resource_group_name = azurerm_resource_group.ama_sample_vm.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_ssh" {
  count = local.vm_count
  # Workaround https://github.com/hashicorp/terraform/issues/24663
  depends_on = [
    azurerm_network_interface.ama_sample_vm,
    azurerm_network_security_group.ssh
  ]
  network_interface_id      = azurerm_network_interface.ama_sample_vm[count.index].id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

data "template_file" "init_script" {
  template = file("./init.sh")
}

resource "azurerm_linux_virtual_machine" "ama_sample_vm" {
  count = local.vm_count
  # Workaround https://github.com/hashicorp/terraform/issues/24663
  depends_on = [
    azurerm_network_interface.ama_sample_vm,
    azurerm_network_interface_security_group_association.nic_ssh
  ]
  name                            = "vm-ama-sample-${count.index}"
  resource_group_name             = azurerm_resource_group.ama_sample_vm.name
  location                        = azurerm_resource_group.ama_sample_vm.location
  size                            = local.vm_size
  admin_username                  = local.vm_admin_user
  disable_password_authentication = true
  allow_extension_operations      = true
  network_interface_ids = [
    azurerm_network_interface.ama_sample_vm[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = local.vm_admin_user
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadOnly"
    storage_account_type = "Standard_LRS"
    diff_disk_settings {
      option = "Local"
    }
    disk_size_gb = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(data.template_file.init_script.rendered)
}

resource "azurerm_virtual_machine_extension" "ama" {
  count                      = local.vm_count
  name                       = "vm-ext-ama-sample-${count.index}"
  virtual_machine_id         = azurerm_linux_virtual_machine.ama_sample_vm[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.5"
  auto_upgrade_minor_version = true

  // Required for Terraform, but optional for the extensions
  settings = <<SETTINGS
    {
        "dummy": "dummy"
    }
SETTINGS
}

// Solution until DCR association is supported. Related to https://github.com/hashicorp/terraform-provider-azurerm/issues/9679
resource "null_resource" "associate_data_collection_rule" {
  count = local.vm_count
  provisioner "local-exec" {
    command = <<EOT
      az monitor data-collection rule association create \
        --name "dcr-assoc-${azurerm_linux_virtual_machine.ama_sample_vm[count.index].name}" \
        --resource ${azurerm_linux_virtual_machine.ama_sample_vm[count.index].id} \
        --rule-id ${var.dcr_id}
EOT
  }
}

# Sample alert definition of platform metrics (Scope: Resouce Group, Type: VM)
resource "azurerm_monitor_metric_alert" "cpu_percentage_sample" {
  name                     = "metrc-alert-cpu-percentage-sample"
  resource_group_name      = azurerm_resource_group.ama_sample_vm.name
  scopes                   = [azurerm_resource_group.ama_sample_vm.id]
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  target_resource_location = azurerm_resource_group.ama_sample_vm.location
  description              = "Action will be triggered when CPU percentage is greater than 80."
  frequency                = "PT5M"
  window_size              = "PT5M"
  severity                 = 2
  auto_mitigate            = true

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = var.action_group_id
  }
}

# Sample alert definition of guest OS metrics (Scope: VM)
resource "azurerm_monitor_metric_alert" "disk_free_percentage_sample" {
  count               = local.vm_count
  name                = "metrc-alert-disk-free-percentage-sample-vm${count.index}"
  resource_group_name = azurerm_resource_group.ama_sample_vm.name
  scopes              = [azurerm_linux_virtual_machine.ama_sample_vm[count.index].id]
  description         = "Action will be triggered when disk free percentage is less than 20."
  frequency           = "PT5M"
  window_size         = "PT5M"
  severity            = 2
  auto_mitigate       = true

  criteria {
    metric_namespace = "Azure.VM.Linux.GuestMetrics"
    metric_name      = "disk/free_percent"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 20
    // https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-troubleshoot-metric#define-an-alert-rule-on-a-custom-metric-that-isnt-emitted-yet
    skip_metric_validation = true

    dimension {
      name     = "Path"
      operator = "Include"
      values   = ["/"]
    }

  }

  action {
    action_group_id = var.action_group_id
  }
}
