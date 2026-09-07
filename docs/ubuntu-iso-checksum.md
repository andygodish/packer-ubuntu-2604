# Ubuntu ISO Checksum Updates

Renovate watches the Ubuntu release directory for newer 26.04 live-server ISO filenames. When a new point release appears, Renovate can update the version references, but it does not update the ISO checksum.

That checksum must be updated manually before merging the Renovate PR.

## Why This Matters

Packer uses `ubuntu_iso_checksum` to verify that the downloaded installer ISO is exactly the artifact this repo expects.

In `ubuntu.pkr.hcl`, the ISO URL is derived from `ubuntu_version`:

```hcl
ubuntu_iso_name = "ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
ubuntu_iso_url  = "https://releases.ubuntu.com/26.04/${local.ubuntu_iso_name}"
```

The checksum is pinned separately:

```hcl
variable "ubuntu_iso_checksum" {
  default = "sha256:..."
}
```

If Renovate changes `ubuntu_version` from `26.04.1` to `26.04.2` but the checksum remains the old `26.04.1` checksum, `packer build` should fail during ISO retrieval or verification. That is the correct failure mode: it prevents building a template from an unverified installer.

## Source Of Truth

Use Ubuntu's checksum file for the matching release directory:

```text
https://releases.ubuntu.com/26.04/SHA256SUMS
```

Find the line for the exact ISO Renovate selected, for example:

```text
ubuntu-26.04.2-live-server-amd64.iso
```

The checksum value from that line becomes:

```hcl
default = "sha256:<checksum>"
```

## Update Process

When reviewing a Renovate PR for a new Ubuntu point release:

1. Check the new `ubuntu_version` value in `ubuntu.pkr.hcl`.
2. Open `https://releases.ubuntu.com/26.04/SHA256SUMS`.
3. Copy the checksum for `ubuntu-<version>-live-server-amd64.iso`.
4. Update `ubuntu_iso_checksum` in `ubuntu.pkr.hcl`.
5. Update the README runtime contract checksum row.
6. Run:

```bash
make validate
```

If building from the Proxmox-side builder VM, also run:

```bash
make build
```

## Files To Check

These files should be consistent before the Renovate PR is merged:

- `ubuntu.pkr.hcl`: `ubuntu_version`
- `ubuntu.pkr.hcl`: `ubuntu_iso_checksum`
- `README.md`: Ubuntu ISO runtime contract row
- `README.md`: ISO checksum runtime contract row
- `version.txt`: release version after `upver` runs
- `CHANGELOG.md`: generated release notes after `upver` runs

## Important Constraint

Do not disable checksum verification to get a build through. A checksum mismatch means the repo is pointing at one ISO version while trusting another ISO version's digest.
