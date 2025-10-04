terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.69"
    }
  }
}

data "proxmox_virtual_environment_vms" "templates" {
  node_name = var.proxmox_node
  tags      = []
}

locals {
  template_id = [for vm in data.proxmox_virtual_environment_vms.templates.vms : vm.vm_id if vm.name == "ubuntu-2404-template" && vm.template][0]
}

provider "proxmox" {
  endpoint = var.proxmox_url
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true

  ssh {
    agent       = false
    username    = "root"
    private_key = file("~/.ssh/id_ecdsa")
  }
}

resource "proxmox_virtual_environment_vm" "test_vm" {
  name      = var.vm_hostname
  node_name = var.proxmox_node

  clone {
    vm_id = local.template_id
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

  initialization {
    datastore_id = "local"
    # This does not work, instead I am leaning on the provisioner
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  connection {
    type        = "ssh"
    user        = "andy"
    private_key = file("~/.ssh/id_ecdsa")
    host        = self.ipv4_addresses[1][0]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${var.vm_hostname}",
      "sudo sed -i 's/ubuntu-template/${var.vm_hostname}/g' /etc/hosts"
    ]
  }

  stop_on_destroy = true
}

# This appears to get deployed, but it loses the race to the original cloud-init and doesn't apply
resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: ${var.vm_hostname}
    fqdn: ${var.vm_hostname}.local
    manage_etc_hosts: true
    preserve_hostname: false
    EOF
    
    file_name = "cloud-init-${var.vm_hostname}.yaml"
  }
}

output "vm_ip" {
  value = proxmox_virtual_environment_vm.test_vm.ipv4_addresses[1][0]
}