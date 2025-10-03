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

  # The url and sha256 checksum - can a tool like renovate be used to keep this updated?
  boot_iso {
    iso_url          = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum     = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    iso_storage_pool = "local"
  }

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = "local"
    format       = "qcow2"
  }

  memory         = 2048
  cores          = 2
  http_directory = "."
  ssh_username   = "ubuntu"
  ssh_password     = "ubuntu"
  boot_key_interval = "150ms"
  boot_wait = "5s"
  boot_command = [
    "c<wait3s>",
    "linux /casper/vmlinuz --- ip=::::::dhcp::: autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ <enter><wait3s>",
    "initrd /casper/initrd<enter><wait3s>",
    "boot<enter>"
  ]
}

build {
  sources = ["source.proxmox-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait"
    ]
  }
}