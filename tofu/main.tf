terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.69"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_url
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "test_vm" {
  name        = "ubuntu-test-vm"
  node_name   = var.proxmox_node
  
  clone {
    vm_id = 111
  }
  
  cpu {
    cores = 2
  }
  
  memory {
    dedicated = 2048
  }
  
  network_device {
    bridge = "vmbr0"
  }
}

output "vm_ip" {
  value = proxmox_virtual_environment_vm.test_vm.ipv4_addresses[1][0]
}