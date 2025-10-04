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

variable "vm_hostname" {
  type        = string
  description = "Hostname for the VM"
  default     = "ubuntu-test"
}