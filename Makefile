# ==============================================================================
# Ubuntu Proxmox Template Build System
# ==============================================================================

UBUNTU_VERSION ?= $(shell sed -n '/variable "ubuntu_version"/,/}/{s/^[[:space:]]*default[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p;}' ubuntu.pkr.hcl | head -n 1 | tr -d '\n\r ')
VERSION_TAG    ?= $(shell [ -s version.txt ] && printf 'v%s\n' $$(cat version.txt | tr -d '[:space:]' | sed 's/^v*//') || echo 'latest')

TEMPLATE_NAME  ?= ubuntu-26-04-1-template
PACKER_FILE    := ubuntu.pkr.hcl
PKRVARS_FILE   ?= ubuntu.pkrvars.hcl
RENOVATE_IMAGE ?= renovate/renovate:44
REPO_ROOT      := $(shell pwd)

.DEFAULT_GOAL := help

.PHONY: verify-env verify-packer init validate build test renovate-validate renovate-dry-run cleanup-build-vm clean fmt help

verify-env:
	@if [ ! -f version.txt ]; then \
		echo "Error: version.txt file missing in repository root."; \
		exit 1; \
	fi
	@if [ ! -f $(PKRVARS_FILE) ]; then \
		echo "Error: $(PKRVARS_FILE) file missing. Copy ubuntu.pkrvars.hcl.example and fill in local Proxmox values."; \
		exit 1; \
	fi

verify-packer:
	@if ! command -v packer >/dev/null 2>&1; then \
		echo "Error: packer binary not found in PATH."; \
		echo "Install Packer, then rerun this target."; \
		exit 1; \
	fi

init: verify-packer
	@echo "Initializing Packer plugins for $(PACKER_FILE)..."
	packer init $(PACKER_FILE)

validate: verify-env init
	@echo "Validating Packer template $(TEMPLATE_NAME) for Ubuntu $(UBUNTU_VERSION)..."
	packer validate -var-file=$(PKRVARS_FILE) $(PACKER_FILE)

build: verify-env init
	@echo "Building Proxmox template $(TEMPLATE_NAME) ($(VERSION_TAG)) from Ubuntu $(UBUNTU_VERSION)..."
	packer build -var-file=$(PKRVARS_FILE) $(PACKER_FILE)

# Packer validation is the local test because the build uploads to and mutates Proxmox.
test: validate

renovate-validate:
	docker run --rm \
		-v $(REPO_ROOT):/usr/src/app \
		-w /usr/src/app \
		$(RENOVATE_IMAGE) \
		renovate-config-validator

renovate-dry-run:
	docker run --rm \
		-v $(REPO_ROOT):/usr/src/app \
		-w /usr/src/app \
		-e LOG_LEVEL=debug \
		-e RENOVATE_CONFIG_FILE=/usr/src/app/renovate.json \
		$(RENOVATE_IMAGE) \
		renovate --platform=local --dry-run=lookup --onboarding=false --require-config=optional

cleanup-build-vm:
	@echo "Packer is configured to request the next free Proxmox VM ID."
	@echo "If a failed temporary build VM remains, identify its VM ID in Proxmox, then run:"
	@echo "  qm stop <vmid>"
	@echo "  qm destroy <vmid> --purge"

clean:
	rm -rf packer_cache output-* downloaded_iso_path

fmt: verify-packer
	packer fmt .

help:
	@echo "Ubuntu Proxmox Template Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make init              Initialize required Packer plugins"
	@echo "  make validate          Initialize and validate the Packer template"
	@echo "  make build             Initialize and build/upload the Proxmox template"
	@echo "  make test              Alias for validate"
	@echo "  make renovate-validate Validate renovate.json with Renovate"
	@echo "  make renovate-dry-run  Run Renovate local lookup dry-run"
	@echo "  make cleanup-build-vm  Print manual Proxmox cleanup guidance"
	@echo "  make fmt               Format Packer files"
	@echo "  make clean             Remove local Packer caches and generated output"
