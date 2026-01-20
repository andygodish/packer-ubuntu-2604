# Packer Ubuntu Template Builder

Automated Ubuntu 24.04 server template creation for Proxmox using HashiCorp Packer.

## Quick Start

```bash
# Validate configuration
make validate

# Build template
make build

# Clean build artifacts
make clean
```

## Prerequisites

- Packer v1.14.2+
- Proxmox VE with API access
- DHCP-enabled network
- 20GB+ free storage on Proxmox

## Project Structure

```bash
.
├── ubuntu.pkr.hcl       # Packer configuration
├── ubuntu.pkrvars.hcl   # Variables (gitignored)
├── user-data            # Cloud-init autoinstall
├── meta-data            # Cloud-init metadata (empty)
├── Makefile             # Build automation
└── README.md            # This file
```

## Configuration

### 1. Create Variables File

Create `ubuntu.pkrvars.hcl`:

```hcl
proxmox_url      = "https://YOUR-PROXMOX-IP:8006/api2/json"
proxmox_username = "root@pam"
proxmox_password = "your-password"
proxmox_node     = "your-node-name"
```

### 2. Generate Password Hash

```bash
# macOS
openssl passwd -6 ubuntu

# Linux
mkpasswd -m sha-512 ubuntu
```

Update the `password` field in `user-data` with the generated hash.

### 3. Customize user-data

Edit `user-data` to customize:

- Hostname
- Locale/keyboard
- Packages
- Network configuration

## Build Process

The build takes approximately 10 minutes and:

1. Downloads Ubuntu 24.04.3 ISO (if not cached)
2. Uploads ISO to Proxmox
3. Creates VM with specified hardware
4. Performs automated installation
5. Updates all packages
6. Converts VM to template
7. Adds cloud-init drive

## Template Details

**Hardware:**

- 2GB RAM
- 2 CPU cores
- 20GB disk (raw format)
- VirtIO network adapter
- SCSI controller

**Software:**

- Ubuntu 24.04.3 LTS
- OpenSSH server
- QEMU guest agent
- Cloud-init
- Latest security updates

**Default Credentials:**

- Username: `ubuntu`
- Password: `ubuntu` (change in production!)
- Sudo: Passwordless

## Using the Template

### Deploy VM from Template

1. Right-click template in Proxmox
2. Select "Clone"
3. Choose "Full Clone"
4. Configure VM settings
5. Start VM

### Cloud-Init Configuration

The template includes a cloud-init drive. Configure via Proxmox UI:

- Cloud-Init tab
- Set user, password, SSH keys
- Configure network settings

## Troubleshooting

### Build Fails with SSH Timeout

**Cause:** Installation taking longer than 20 minutes.

**Solution:** Increase `ssh_timeout` in `ubuntu.pkr.hcl`.

### VM Has No Network After Boot

**Cause:** Missing cloud-init configuration.

**Solution:** Ensure `cloud_init = true` is set in configuration.

### Boot Hangs at Language Selection

**Cause:** Boot commands not executing properly.

**Solutions:**

- Verify `http_directory` is correct
- Check `user-data` and `meta-data` files exist
- Ensure DHCP is available on network

### Installation Hangs at "Waiting for Network"

**Cause:** systemd network wait timeout.

**Solution:** The `early-commands` in `user-data` should handle this. If persists, check DHCP server availability.

## Extending to Other Platforms

### Add AWS Builder

```hcl
source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-24.04-{{timestamp}}"
  instance_type = "t3.medium"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  sources = [
    "source.proxmox-iso.ubuntu",
    "source.amazon-ebs.ubuntu"
  ]
  
  # Shared provisioning
}
```

## Maintenance

### Update Ubuntu ISO

1. Download new ISO from [ubuntu release page](https://releases.ubuntu.com/24.04/)
2. Get SHA256 checksum from `SHA256SUMS` file
3. Update `iso_url` and `iso_checksum` in `ubuntu.pkr.hcl`
4. Run `make validate` and `make build`

### Clean Old Builds

```bash
# Remove cached ISOs and build artifacts
make clean

# Remove specific cache
rm -rf packer_cache/
rm -rf downloaded_iso_path/
```

## Security Notes

- **Never commit** `ubuntu.pkrvars.hcl` to version control
- Change default password in production deployments
- Consider using SSH keys instead of passwords
- Update template regularly for security patches
- Use API tokens instead of root password when possible

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Template

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-packer@main
      
      - name: Validate
        run: make validate
        env:
          PROXMOX_URL: ${{ secrets.PROXMOX_URL }}
          PROXMOX_USER: ${{ secrets.PROXMOX_USER }}
          PROXMOX_PASS: ${{ secrets.PROXMOX_PASS }}
          PROXMOX_NODE: ${{ secrets.PROXMOX_NODE }}
      
      - name: Build
        run: make build
```

## References

- [Packer Documentation](https://developer.hashicorp.com/packer)
- [Proxmox Plugin](https://developer.hashicorp.com/packer/plugins/builders/proxmox/iso)
- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init](https://cloudinit.readthedocs.io/)

## License

This project is provided as-is for educational and operational purposes.

## Contributing

Improvements welcome! Key areas:

- Additional OS support (Debian, Rocky, etc.)
- Enhanced security hardening
- Automated testing
- Multi-platform builds
