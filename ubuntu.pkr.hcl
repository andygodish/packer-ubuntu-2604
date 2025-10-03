packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username"
}

variable "proxmox_password" {
  type        = string
  sensitive   = true
  description = "Proxmox password"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  vm_name              = "ubuntu-2404-template"
  template_description = "Ubuntu 24.04 base template"

  boot_iso {
    iso_url          = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum     = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    iso_storage_pool = "local"
    unmount          = true
  }

  memory  = 2048
  cores   = 2
  sockets = 1
  os      = "l26"

  qemu_agent      = true
  scsi_controller = "virtio-scsi-single"

  network_adapters {
    model       = "virtio"
    bridge      = "vmbr0"
    mac_address = "repeatable"
    mtu         = 1
  }

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = "local"
    format       = "raw"
  }

  cloud_init              = true
  cloud_init_storage_pool = "local"

  http_directory    = "."
  boot_wait         = "10s"
  boot_key_interval = "150ms"

  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- ip=::::::dhcp::: autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'<enter><wait5s>",
    "initrd /casper/initrd<enter><wait5s>",
    "boot<enter><wait5s>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }
}