PACKER_VERSION := 1.9.4
PACKER_LOG := 1
PWN_HOSTNAME := pwnagotchi
PWN_VERSION := $(shell cut -d"'" -f2 < pwnagotchi/_version.py)
PWN_RELEASE := pwnagotchi-raspios-lite-$(PWN_VERSION)

MACHINE_TYPE := $(shell uname -m)
ifneq (,$(filter x86_64,$(MACHINE_TYPE)))
GOARCH := amd64
else ifneq (,$(filter i686,$(MACHINE_TYPE)))
GOARCH := 386
else ifneq (,$(filter arm64% aarch64%,$(MACHINE_TYPE)))
GOARCH := arm64
else ifneq (,$(filter arm%,$(MACHINE_TYPE)))
GOARCH := arm
else
GOARCH := amd64
$(warning Unable to detect CPU arch from machine type $(MACHINE_TYPE), assuming $(GOARCH))
endif

# The Ansible part of the build can inadvertently change the active hostname of
# the build machine while updating the permanent hostname of the build image.
# If the unshare command is available, use it to create a separate namespace
# so hostname changes won't affect the build machine.
UNSHARE := $(shell command -v unshare)
ifneq (,$(UNSHARE))
UNSHARE := $(UNSHARE) --uts
endif

all: clean image

langs:
	@for lang in pwnagotchi/locale/*/; do\
		echo "compiling language: $$lang ..."; \
		./scripts/language.sh compile $$(basename $$lang); \
	done

PACKER := /usr/bin/packer
PACKER_URL := https://releases.hashicorp.com/packer/$(PACKER_VERSION)/packer_$(PACKER_VERSION)_linux_$(GOARCH).zip
$(PACKER):
	mkdir -p $(@D)
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
	sudo apt-get update && sudo apt-get install packer
	$(PACKER) plugins install github.com/solo-io/arm-image

SDIST := dist/pwnagotchi-$(PWN_VERSION).tar.gz
$(SDIST): setup.py pwnagotchi
	python3 setup.py sdist

# Building the image requires packer, but don't rebuild the image just because packer updated.
$(PWN_RELEASE).img: | $(PACKER)

base32: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=arm-image.base-pwnagotchi pwnagotchi.json.pkr.hcl

# If the packer or ansible files are updated, rebuild the image.
base64: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=arm-image.base-pwnagotchi64 pwnagotchi.json.pkr.hcl

# If the packer or ansible files are updated, rebuild the image.
$(PWN_RELEASE).img: $(SDIST) builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=arm-image.pwnagotchi pwnagotchi.json.pkr.hcl

# If the packer or ansible files are updated, rebuild the image.
image64: $(SDIST) builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.pwnagotchi64 pwnagotchi.json.pkr.hcl

orangepwn02w: $(SDIST) builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.orangepwn02w pwnagotchi.json.pkr.hcl

bananapwnm2zero: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.bananapwnm2zero pwnagotchi.json.pkr.hcl

bananapwnm4zero: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.bananapwnm4zero pwnagotchi.json.pkr.hcl

bananas: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.bananapwn\*zero pwnagotchi.json.pkr.hcl


images: $(SDIST) builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.pwnagotchi64,\*.pwnagotchi pwnagotchi.json.pkr.hcl

bases: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.base-pwnagotchi,\*.base-pwnagotchi64 pwnagotchi.json.pkr.hcl

allimages: builder/pwnagotchi.json.pkr.hcl builder/pwnagotchi.yml $(shell find builder/data -type f)
	cd builder && $(UNSHARE) $(PACKER) build -var "pwn_hostname=$(PWN_HOSTNAME)" -var "pwn_version=$(PWN_VERSION)" -only=\*.pwnagotchi,\*.pwnagotchi64,\*.orangepwn02w,\*.bananapwnm\*zero pwnagotchi.json.pkr.hcl


# If any of these files are updated, rebuild the checksums.
$(PWN_RELEASE).sha256: $(PWN_RELEASE).img
	sha256sum $^ > $@

# If any of the input files are updated, rebuild the archive.
$(PWN_RELEASE).zip: $(PWN_RELEASE).img $(PWN_RELEASE).sha256
	zip $(PWN_RELEASE).zip $^

.PHONY: image
image: $(PWN_RELEASE).zip

clean:
	- #python3 setup.py clean --all
	- rm -rf dist pwnagotchi.egg-info
	- rm -f $(PACKER)
	- rm -f $(PWN_RELEASE).*
	- sudo rm -rf builder/output-pwnagotchi builder/packer_cache

