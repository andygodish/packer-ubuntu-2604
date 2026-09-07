# Proxmox Packer Build Notes

This document records the debugging path for getting the Ubuntu 26.04 Proxmox template build working. Keep this separate from the README so the README can stay focused on normal operation.

## Working Outcome

The build completed successfully and produced this Proxmox template:

```text
ubuntu-26-04-1-template
```

The successful build path was:

1. Run Packer from an Ubuntu builder VM on the Proxmox-side LAN, not from the Mac/devcontainer path.
2. Let the Ubuntu installer keep the boot-time DHCP network state by omitting a top-level autoinstall `network:` stanza.
3. Keep apt mirror configuration explicit and disable geo mirror selection.
4. Install `qemu-guest-agent` during autoinstall and enable it in `late-commands`.
5. Do not wait for `/var/lib/cloud/instance/boot-finished` in the Packer shell provisioner.

## Why The Mac/Devcontainer Path Failed

Packer serves autoinstall seed data from the machine running Packer. The temporary Proxmox installer VM must reach URLs like:

```text
http://<packer-http-ip>:<packer-http-port>/user-data
http://<packer-http-ip>:<packer-http-port>/meta-data
```

When Packer ran from the Mac or devcontainer path, the temporary VM had trouble reaching that HTTP server reliably. The previous `packer-lab` notes recorded the same behavior: running Packer from an Ubuntu VM on Proxmox completed successfully.

## Failure Modes Seen

### Packer Timed Out Waiting For SSH

Symptom:

```text
==> proxmox-iso.ubuntu: Waiting for SSH to become available...
==> proxmox-iso.ubuntu: Timeout waiting for SSH.
```

This had multiple possible causes during debugging:

- The installer did not consume the NoCloud autoinstall seed.
- The installer failed before installing or starting SSH.
- The VM installed and SSH worked, but Packer could not discover the guest IP.

The most useful check was opening the temporary VM console in Proxmox and looking at the installer state directly.

### Offline Install / cdrom Apt Repository

Symptom from the failed installer shell:

```bash
apt-get indextargets
```

returned only entries like:

```text
Repo-URI: file:/cdrom/
Site: file:/cdrom
```

Subiquity logs showed:

```text
Skipping mirror check since network is not available.
```

Even though the VM later had working IPv4, DNS, and HTTP access, Subiquity had already chosen the offline install path. The offline ISO repository did not contain `qemu-guest-agent`, so package installation failed.

The effective fix was to remove the top-level autoinstall `network:` stanza and let the installer retain the DHCP network brought up by the kernel boot command.

### qemu-guest-agent Package Failure

Symptom:

```text
curtin system-install -t /target --download-only -- qemu-guest-agent
returned non-zero exit status 100
```

This was a symptom of the offline apt repository path, not a problem with `qemu-guest-agent` itself.

The agent should remain in the autoinstall package list because the Proxmox Packer builder needs Proxmox to discover the guest IP reliably.

### qemu-guest-agent Late Command Failure

Symptom:

```text
curtin in-target --target=/target -- systemctl enable qemu-guest-agent
returned non-zero exit status 1
```

This happened when `qemu-guest-agent` had been removed from the autoinstall package list but the late-command still tried to enable it. The coherent choices are:

- Install `qemu-guest-agent` during autoinstall, then enable it in `late-commands`.
- Or do not use guest-agent discovery and use a fixed SSH host/IP instead.

This repo uses the first option.

### Cloud-init Wait Hung Forever

Symptom:

```text
==> proxmox-iso.ubuntu: Waiting for cloud-init...
```

On the guest:

```bash
cloud-init status --long
```

reported:

```text
status: not started
boot_status_code: enabled-by-generator
```

The Packer provisioner was waiting for:

```text
/var/lib/cloud/instance/boot-finished
```

but that file was never created in this template-build state. The fix was to remove that wait from the Packer shell provisioner. SSH availability is the readiness gate Packer needs for the remaining `apt-get update` and `apt-get upgrade` commands.

## Network Settings That Mattered

The Packer VM network block should avoid unusual MTU values:

```hcl
network_adapters {
  model  = "virtio"
  bridge = "vmbr0"
}
```

A prior config had:

```hcl
mtu = 1
```

That is not appropriate for normal VM networking and was removed.

A pinned MAC was tried during debugging, but it should not remain in the template builder config. Let Proxmox assign MAC addresses dynamically so cloned VMs do not inherit duplicate addresses.

## Useful Debug Commands

From a failed installer shell:

```bash
cat /proc/cmdline
ip -br addr
ip route
resolvectl status
apt-get indextargets | sed -n '1,80p'
tail -80 /var/log/installer/subiquity-server-info.log
cat /var/log/installer/subiquity-traceback.txt
```

To check whether SSH and the guest agent are present after a partial install:

```bash
systemctl status ssh --no-pager
dpkg -l qemu-guest-agent cloud-init openssh-server | cat
```

From the builder VM, direct SSH was useful to prove the guest was reachable even when Packer could not discover it:

```bash
ssh ubuntu@<temporary-vm-ip>
```

## Cleanup After Failed Builds

Packer should delete failed build VMs, but interrupted or failed runs can leave temporary VMs behind. If that happens, identify the VM ID in Proxmox and run these commands on the Proxmox node:

```bash
qm stop <vmid>
qm destroy <vmid> --purge
```

The Makefile helper only prints this guidance:

```bash
make cleanup-build-vm
```
