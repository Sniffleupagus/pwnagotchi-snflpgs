packer {
  required_plugins {
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "pwn_hostname" {
  type = string
  default = "pwnagotchi"
}

variable "pwn_version" {
  type = string
  description = "Pwnagotchi software version"
}

variable "stage_root" {
  type = string
  description = "Path to staging directory"
  default = "../build/stage"
}

variable "image_root" {
  type = string
  description = "Path to disk image directory"
  default = "../build/images"
}

variable "target_image_size" {
  type = string
  description = "Size of image to build in bytes"
  default = "9368709120"
}

source "arm-image" "pwnagotchi" {
  output_filename   = "${var.image_root}/${source.name}-${var.pwn_version}.img"
  target_image_size = "${var.target_image_size}"
}

source "arm-image" "base_image" {
  output_filename   = "${var.image_root}/${source.name}-${var.pwn_version}.img"
  target_image_size = "${var.target_image_size}"
}

build {
  source "source.arm-image.base_image" {
    name = "base-pwnagotchi"
    iso_checksum      = "file:https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz.sha256"
    iso_url           = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz"
    qemu_args         = ["-cpu", "arm1176"]
    image_arch        = "arm"
  }
  
  source "source.arm-image.base_image" {
    name = "base-pwnagotchi64"
    iso_checksum      = "file:https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz.sha256"
    iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
    image_arch = "arm64"
  }

  source "source.arm-image.pwnagotchi" {
    name = "pwnagotchi"
    iso_url   = "file:${abspath(var.image_root)}/base-${source.name}-${var.pwn_version}.img.xz"
    iso_checksum   = "none"
    image_type     = "raspberrypi"
    qemu_args         = ["-cpu", "arm1176"]
    image_arch        = "arm"
  }

  source "source.arm-image.pwnagotchi" {
    name = "pwnagotchi64"
    iso_url   = "file:${abspath(var.image_root)}/base-${source.name}-${var.pwn_version}.img.xz"
    iso_checksum   = "none"
    image_type     = "raspberrypi"
    image_arch = "arm64"
  }

  source "source.arm-image.pwnagotchi" {
    name = "orangepwn02w"
    iso_checksum      = "none"
    iso_url           = "file:${abspath(var.image_root)}/Orangepizero2w_base.img.xz"
    image_type        = "armbian"
    image_arch        = "arm64"
    qemu_args         = ["-r", "6.1.31-sun50iw9"]
  }

  source "source.arm-image.pwnagotchi" {
    name = "bananapwnm2zero"
    iso_checksum      = "none"
    iso_url           = "file:${abspath(var.image_root)}/Armbian_23.11.0-trunk_Bananapim2zero_bullseye_current_6.1.62_minimal.img"
    image_type        = "armbian"
    image_arch        = "arm"
    qemu_args         = ["-r", "6.1.63-current-sunxi"]
  }

  source "source.arm-image.pwnagotchi" {
    name = "bananapwnm4zero"
    iso_checksum      = "none"
    iso_url           = "file:${abspath(var.image_root)}/BananaPiM4Zero/Bpi-m4zero_1.0.0_debian_bullseye_minimal_linux6.1.31.img"
    image_type        = "armbian"
    image_arch        = "arm64"
    qemu_args         = ["-r", "6.1.31-sun50iw9"]
  }

  
  provisioner "shell-local" {
    inline = [
      "curl -s -d 'Build ${source.name} starting' ntfy.sh/pwny_builder",
      "echo ${build.name}",
      "pwd",
      "printenv"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "echo 'Creating stage directory for ${source.name}'",
      "mkdir -p /tmp/staging_${source.name}",
      "ls -ld /tmp/sta*",
      "if [ -f ${abspath(var.stage_root)}/staged_${source.name}.tgz ]; then",
      "  echo 'Unpacking staged files:'",
      "  tar -C /tmp/staging_${source.name} -xvzf ${var.stage_root}/staged_${source.name}.tgz",
      "else",
      "  echo looking for ${source.name} in  ${abspath(var.stage_root)}",
      "  ls -l ${abspath(var.stage_root)}",
      "fi",
      "if [ ! -d '${var.stage_root}/incoming}' ]; then",
      "  echo '-> Creating ${var.stage_root}/incoming directory for new artifacts'",
      "  mkdir -p ${var.stage_root}/incoming",
      "fi"
    ]
  }

  provisioner "shell-local" {
    only = ["arm-image.bananapwnm2zero", "arm-image.pwnagotchi", "arm-image.base-pwnagotchi"]
    inline = [
      "if [ -f '${var.stage_root}/go_pkgs.tgz' ]; then",
      "  echo 'Copying go packages'",
      "  cp ${var.stage_root}/go_pkgs.tgz /tmp/staging_${source.name}/",
      "  ls -l /tmp/staging_${source.name}",
      "fi"
    ]
  }

  provisioner "file" {
    destination = "/root/staging/"
    source      = "/tmp/staging_${source.name}/"
    generated   = true
  }

  provisioner "shell" {
    only = ["arm-image.bananapwnm2zero", "arm-image.pwnagotchi"]
    inline = [
      "if [ -f /root/staging/go_pkgs.tgz ]; then",
      "  echo Installing go packages to help go mod tidy under arm emulation",
      "  tar -C /root -xvzf /root/staging/go_pkgs.tgz | tail",
      "  rm /root/staging/go_pkgs.tgz",
      "fi"
    ]
  }

  provisioner "file" {
    destination = "/usr/bin/"
    sources     = [
      "../builder/data/usr/bin/"
    ]
  }

  provisioner "file" {
    except = ["arm-image.bananapwnm2zero"]
    destination = "/etc/"
    sources     = [
      "../builder/data/etc/"
    ]
  }

  provisioner "shell" {
    inline = ["chmod +x /usr/bin/*"]
  }

  provisioner "shell" {
    inline = ["chmod +x /etc/update-motd.d/*"]
  }

  provisioner "shell" {
    only = ["arm-image.base-pwnagotchi", "arm-image.base-pwnagotchi64", "arm-image.pwnagotchi", "arm-image.pwnagotchi64"]
    inline = [
      "echo Install kernel headers",
      "apt-get install -y raspberrypi-kernel-headers",
      "apt-mark hold raspberrypi-kernel raspberrypi-kernel-headers"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo '>>>-----> APT UPDATE <-----<<<'",
      "apt-get -y --allow-releaseinfo-change update",
      "echo '==>-----> APT UPGRADE <-----<=='",
      "#apt-get -y upgrade",
      "echo '###======]> INSTALLING ANSIBLE <[=====###'",
      "apt-get install -y ansible binfmt-support python3-venv"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "curl -s -d 'Build ${source.name} starting ansible' ntfy.sh/pwny_builder"
    ]
  }

  provisioner "ansible-local" {
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_BUILD=${source.name} PWN_VERSION=${var.pwn_version} PWN_HOSTNAME=${var.pwn_hostname} ansible-playbook"
    extra_arguments = ["--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"", "-v" ]
    playbook_dir    = "../builder/"
    playbook_file   = "../builder/pwnagotchi.yml"
    override = {
      "base-pwnagotchi" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only64,pwnagotchi,no_raspi,no_base"
	] },
      "base-pwnagotchi64" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only32,pwnagotchi,no_raspi,no_base"
	] },
      "pwnagotchi" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only64,no_raspi"
	] },
      "pwnagotchi64" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only32,no_raspi"
	] },
      "orangepwn02w" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3 kernel.full=6.1.31-sun50iw9\"",
	  "-v",
	  "--skip-tags", "only32,no_orangepi"
	] },
      "bananapwnm4zero" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3 kernel.full=6.1.31-sun50iw9\"",
	  "-v",
	  "--skip-tags", "only32,no_bananapi,no_bananapim4zero"
	] },
      "bananapwnm2zero" = {
	extra_arguments = [
	  "--extra-vars", "\"ansible_python_interpreter=/usr/bin/python3 kernel.full=6.1.62-current-sunxi\"",
	  "-v",
	  "--skip-tags", "only64,no_bananapi,no_bananapim2zero"
	] }
    } 
  }

  provisioner "shell" {
    inline = [
      "echo Directory Download not implemented, so doing it the old fashioned way",
      "echo Creating archive of /root/staging",
      "tar -C /root/staging --exclude '*~' --exclude '*.bak' -cvzf /root/staging.tgz ."
    ]
  }

  provisioner "file" {
    destination = "${var.stage_root}/incoming/staged_${source.name}.tgz"
    direction   = "download"
    source      = "/root/staging.tgz"
  }

  provisioner "shell" {
    inline = [
      "echo Removing staging directory from image",
      "rm -rf /root/staging /root/staging.tgz"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "echo ADD FEATURE compress and sha256sum the image",
      "#cd $(dirname $ { source.output_filename})",
      "#fname=$(basename $ { build.output_filename})",
      "#xz $fname",
      "#sha256sum $fname > $fname.sha256"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "echo '[|}=- Job is complete. Take a deep breath. -={|]'",
      "curl -s -d 'Build ${source.name} completed' ntfy.sh/pwny_builder"
    ]
  }

  error-cleanup-provisioner "shell-local" {
    inline = [
      "echo '[|}=- Build failed. Take a deep breath. -={|]'",
      "curl -s -d 'Build ${source.name} failed' ntfy.sh/pwny_builder"
    ]
  }

  post-processors {
    post-processor "manifest" {
      output = "${var.image_root}/manifest.json"
      strip_path = true
    }
    
    post-processor "shell-local" {
      inline = [
	"cd /pwnystable/images",
	"echo \"Looking for $PACKER_RUN_UUID\"",
	"jq \".builds[].files[].name\" manifest.json | xargs ls -l",
	"jq '.builds[] | select(.packer_run_uuid==\"$PACKER_RUN_UUID\") | .files[].name' manifest.json | xargs -P 4 -n 1 echo xz --keep"

      ]
    }

    post-processor "artifice" {
      keep_input_artifact = "true"
      files = [ "${source.name}-${var.pwn_version}.img.xz" ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output="${var.image_root}/pwnagotchi-image-checksums.{{.ChecksumType}}"
      
    }
  }
}
