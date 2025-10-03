.PHONY: validate build clean

validate:
	packer validate -var-file=ubuntu.pkrvars.hcl ubuntu.pkr.hcl

build:
	packer build -var-file=ubuntu.pkrvars.hcl ubuntu.pkr.hcl

clean:
	rm -rf packer_cache output-*

fmt:
	packer fmt .