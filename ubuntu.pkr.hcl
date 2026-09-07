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


# renovate: datasource=custom.ubuntu-releases depName=ubuntu-live-server-amd64 versioning=loose
variable "ubuntu_version" {
  type        = string
  description = "Ubuntu live-server ISO version"
  default     = "26.04.1"
}

variable "ubuntu_iso_checksum" {
  type        = string
  description = "SHA256 checksum for the pinned Ubuntu live-server ISO"
  default     = "sha256:cc8a95cde20f6ced61a322420de00f10cc3c90ced545daa46cb9c1a117f1d927"
}

variable "install_docker" {
  type        = bool
  description = "Install Docker Engine and Compose plugin into the template"
  default     = true
}

locals {
  ubuntu_version_name = replace(var.ubuntu_version, ".", "-")
  ubuntu_iso_name = "ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
  ubuntu_iso_url  = "https://releases.ubuntu.com/26.04/${local.ubuntu_iso_name}"
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  vm_name              = "ubuntu-${local.ubuntu_version_name}-template"
  template_description = "Ubuntu ${var.ubuntu_version} base template"

  boot_iso {
    iso_url          = local.ubuntu_iso_url
    iso_checksum     = var.ubuntu_iso_checksum
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
    "linux /casper/vmlinuz --- autoinstall ip=dhcp ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}'<enter><wait5s>",
    "initrd /casper/initrd<enter><wait5s>",
    "boot<enter><wait5s>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "45m"
}

build {
  sources = ["source.proxmox-iso.ubuntu"]

  provisioner "file" {
    source      = "version.txt"
    destination = "/tmp/packer-ubuntu-2604-version.txt"
  }

  provisioner "shell" {
    inline = [
      "sudo install -d -m 0755 /etc/packer-ubuntu-2604",
      "sudo install -m 0644 /tmp/packer-ubuntu-2604-version.txt /etc/packer-ubuntu-2604/version.txt",
      "sudo rm -f /tmp/packer-ubuntu-2604-version.txt"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "INSTALL_DOCKER=${var.install_docker}"
    ]

    inline = [
      "if [ \"$INSTALL_DOCKER\" != \"true\" ]; then echo \"Skipping Docker installation.\"; exit 0; fi",
      "sudo apt-get install -y ca-certificates curl gnupg",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      ". /etc/os-release && echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $${VERSION_CODENAME} stable\" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu"
    ]
  }
}
