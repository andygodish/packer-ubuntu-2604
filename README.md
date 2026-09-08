# Ubuntu 26.04 Packer Template

Builds a pinned Ubuntu Server template for Proxmox using Packer.

This repo is part of the standalone `packer-*` series: it owns template build inputs and the Proxmox template artifact, but it does not deploy long-lived VMs. Instance deployment belongs in separate `tofu-*` repos.

## Runtime Contract

| Requirement | Value |
| --- | --- |
| Builder | Packer `proxmox-iso` |
| Ubuntu ISO | `ubuntu-26.04.1-live-server-amd64.iso` |
| ISO checksum | `sha256:cc8a95cde20f6ced61a322420de00f10cc3c90ced545daa46cb9c1a117f1d927` |
| Proxmox artifact | VM template |
| Template name | `ubuntu-26-04-1-template` |
| Template disk | `20G` raw on `local` |
| Template memory | `2048` MB |
| Template CPU | `2` cores |
| Network | `vmbr0`, DHCP |
| Cloud-init | enabled on Proxmox `local` storage |
| Container runtime | Docker Engine from Docker apt repo when `install_docker = true`, unpinned at template build time |
| Build tooling | Packer CLI from HashiCorp apt repo when `install_packer = true`, unpinned at template build time |
| Object storage tooling | MinIO Client `mc` from the official MinIO binary download when `install_minio_client = true`, unpinned at template build time |

Packer downloads the pinned Ubuntu installer ISO, uploads/uses it through Proxmox, serves the checked-in autoinstall seed files, installs Ubuntu into a temporary VM, runs provisioning, and converts the result to a reusable Proxmox template.

## Versioning

`version.txt` is the local release tag source. The upstream dependency pin is `ubuntu_version` in `ubuntu.pkr.hcl`.

`upver.yaml` links both so upstream Ubuntu ISO changes can produce sequence release tags such as:

```text
26.04.1-0
26.04.1-1
26.04.2-0
```

Container-style release tags should still be normalized with one leading `v` when git tags are created, for example `v26.04.1-0`.

## Renovate

`renovate.json` is optional but useful as a point-release notifier for the Ubuntu 26.04 release directory. It watches the live-server ISO filename and can open a PR when media such as `26.04.2` appears.

Renovate does not update `ubuntu_iso_checksum` in this repo. When Renovate updates `ubuntu_version`, update the checksum from Ubuntu's `SHA256SUMS` file before building. The manual checksum process is documented in docs/ubuntu-iso-checksum.md. If that manual checksum step becomes noisy, remove Renovate or replace it with a small checksum-aware updater.

## Local Configuration

Create a local variable file from the example:

```bash
cp ubuntu.pkrvars.hcl.example ubuntu.pkrvars.hcl
```

Then fill in Proxmox connection details:

```hcl
proxmox_url      = "https://YOUR-PROXMOX-IP:8006/api2/json"
proxmox_username = "root@pam"
proxmox_password = "your-password"
proxmox_node     = "your-node-name"
```

`ubuntu.pkrvars.hcl` is ignored because it usually contains secrets. Prefer Proxmox API tokens over root passwords when this template is next revised.

## Network Notes

Packer should let Proxmox assign VM MAC addresses dynamically. Do not pin a MAC in the template builder config because that value can persist into cloned VMs and cause network conflicts.

## Troubleshooting Notes

Detailed notes from debugging the Proxmox/Packer build path are in docs/proxmox-packer-build-notes.md.

## Operational Guide

Run these commands inside the `packer-ubuntu-2604` directory.

```bash
make validate
make build
```

Other useful targets:

```bash
make test
make fmt
make clean
```

`make test` aliases `make validate` because `make build` talks to Proxmox and creates/replaces infrastructure artifacts.

The built template records the packer project version at `/etc/packer-ubuntu-2604/version.txt`. Check a cloned VM with `cat /etc/packer-ubuntu-2604/version.txt`.

## Autoinstall

The checked-in `user-data` file configures the Ubuntu autoinstall. It installs OpenSSH, the QEMU guest agent, and `make`, then enables cloud-init support for cloned VMs. Packer provisioning installs the MinIO Client `mc` binary from MinIO's official download endpoint when `install_minio_client = true`. It installs Docker Engine, Buildx, and the Compose plugin from Docker's apt repo when `install_docker = true`, enables Docker and containerd at boot, and runs `docker version` as a build-time smoke test so cloned VMs are ready for compose-backed services. Set `install_docker = false`, `install_packer = false`, or `install_minio_client = false` in `ubuntu.pkrvars.hcl` to build a smaller base template without those tools.

The default installer identity is only for the template build path. Review users, SSH keys, and password settings before treating this as a production baseline.

## Out Of Scope

This repo should not contain OpenTofu/Terraform state, providers, plans, or VM deployment resources. Clone/deploy logic for specific services should live in a future `tofu-*` repo.
