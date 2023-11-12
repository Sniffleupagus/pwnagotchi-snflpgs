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
}

variable "pwn_version" {
  type = string
}


source "arm-image" "base-image" {
  iso_checksum      = "file:/home/vagrant/images/2023-05-03-raspios-bullseye-armhf-lite.img.xz.sha256"
  iso_url           = "file:/home/vagrant/images/2023-05-03-raspios-bullseye-armhf-lite.img.xz"
  output_filename   = "/pwnystable/images/base_raspios-bullseye-armhf.img"
  qemu_args         = ["-cpu", "arm1176"]
  image_arch        = "arm"
  target_image_size = 9368709120
}

source "arm-image" "base64-image" {
  iso_checksum      = "file:/home/vagrant/images/2023-05-03-raspios-bullseye-arm64-lite.img.xz.sha256"
  iso_url           = "file:/home/vagrant/images/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
  output_filename   = "/pwnystable/images/base_raspios-bullseye-aarch64.img"
  image_arch        = "arm64"
  target_image_size = 9368709120
}

source "arm-image" "pwnagotchi" {
  iso_checksum      = "file:/pwnystable/images/base_raspios-bullseye-armhf.img.xz.sha256"
  iso_url           = "file:/pwnystable/images/base_raspios-bullseye-armhf.img.xz"
  output_filename   = "/pwnystable/images/pwnagotchi-${var.pwn_version}-armhf.img"
  qemu_args         = ["-cpu", "arm1176"]
  image_arch        = "arm"
  target_image_size = 9368709120
}

source "arm-image" "pwnagotchi64" {
  iso_checksum      = "file:/pwnystable/images/base_raspios-bullseye-aarch64.img.xz.sha256"
  iso_url           = "file:/pwnystable/images/base_raspios-bullseye-aarch64.img.xz"
  output_filename   = "/pwnystable/images/pwnagotchi-${var.pwn_version}-aarch64.img"
  image_arch        = "arm64"
  target_image_size = 9368709120
}

source "arm-image" "orangepwn02w" {
  iso_checksum      = "file:/vagrant/Orangepizero2w_base.img.xz.sha256"
  iso_url           = "file:/vagrant/Orangepizero2w_base.img.xz"
  image_type        = "armbian"
  output_filename   = "/pwnystable/images/pwnagotchi-${var.pwn_version}-orangepi02w.img"
  qemu_args         = ["-r", "6.1.31-sun50iw9"]
  image_arch        = "arm64"
  target_image_size = 9368709120
}

source "arm-image" "bananapim2zero" {
  iso_checksum      = "file:/home/vagrant/lgit/armbian-build/output/images/Armbian_23.11.0-trunk_Bananapim2zero_bullseye_current_6.1.62_minimal.img.sha"
  iso_url           = "/home/vagrant/lgit/armbian-build/output/images/Armbian_23.11.0-trunk_Bananapim2zero_bullseye_current_6.1.62_minimal.img"
  image_type        = "armbian"
  output_filename   = "/pwnystable/images/pwnagotchi-${var.pwn_version}-${source.name}.img"
  qemu_args         = ["-r", "6.1.62-current-sunxi"]
  image_arch        = "arm"
  target_image_size = 9368709120
}

build {
  sources = [
    "source.arm-image.base-image",
    "source.arm-image.base64-image",
    "source.arm-image.pwnagotchi",
    "source.arm-image.pwnagotchi64",
    "source.arm-image.orangepwn02w",
    "source.arm-image.bananapim2zero"
  ]

  provisioner "file" {
    except = ["arm-image.bananapim2zero"]
    destination = "/root/staging/"
    source      = "../../staging/"
  }

  provisioner "file" {
    only = ["arm-image.bananapim2zero", "arm-image.pwnagotchi"]
    destination = "/root/"
    source      = "../../spool/go_pkgs.tgz"
  }

  provisioner "shell" {
    only = ["arm-image.bananapim2zero", "arm-image.pwnagotchi"]
    inline = [
      "echo Installing go packages to help go mod tidy under arm emulation",
      "tar -C /root -xzf /root/go_pkgs.tgz",
      "rm /root/go_pkgs.tgz"
    ]
  }

  provisioner "file" {
    destination = "/usr/bin/"
    sources     = [
      "../builder/data/usr/bin/pwnlib",
      "../builder/data/usr/bin/bettercap-launcher",
      "../builder/data/usr/bin/pwnagotchi-launcher", "../builder/data/usr/bin/pwngrid-launcher",
      "../builder/data/usr/bin/monstop",
      "../builder/data/usr/bin/monstart",
      "../builder/data/usr/bin/hdmion",
      "../builder/data/usr/bin/hdmioff"
    ]
  }

  provisioner "file" {
    except = ["arm-image.bananapim2zero"]
    destination = "/etc/network/interfaces.d/"
    sources     = [
      "../builder/data/etc/network/interfaces.d/lo-cfg",
      "../builder/data/etc/network/interfaces.d/wlan0-cfg",
      "../builder/data/etc/network/interfaces.d/usb0-cfg",
      "../builder/data/etc/network/interfaces.d/eth0-cfg"
    ]
  }

  provisioner "file" {
    destination = "/etc/systemd/system/"
    sources     = [
      "../builder/data/etc/systemd/system/pwngrid-peer.service",
      "../builder/data/etc/systemd/system/pwnagotchi.service",
      "../builder/data/etc/systemd/system/bettercap.service"
    ]
  }

  provisioner "shell" {
    inline = ["chmod +x /usr/bin/*"]
  }

  provisioner "file" {
    destination = "/etc/update-motd.d/01-motd"
    source      = "../builder/data/etc/update-motd.d/01-motd"
  }

  provisioner "shell" {
    inline = ["chmod +x /etc/update-motd.d/*"]
  }

  provisioner "shell" {
    only = ["arm-image.base-image", "arm-image.base64-image", "arm-image.pwnagotchi", "arm-image.pwnagotchi64"]
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
      "apt-get -y upgrade",
      "echo '###======]> INSTALLING ANSIBLE <[=====###'",
      "apt install -y ansible"
    ]
  }

  provisioner "ansible-local" {
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${var.pwn_version} PWN_HOSTNAME=${var.pwn_hostname} ansible-playbook"
    extra_arguments = ["--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"", "-vv" ]
    playbook_dir    = "../builder/"
    playbook_file   = "../builder/pwnagotchi.yml"
    override = {
      "base-image" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only64,pwnagotchi,no_raspi"
	] },
      "base64-image" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"",
	  "-v",
	  "--skip-tags", "only32,pwnagotchi,no_raspi"
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
      "bananapim2zero" = {
	extra_arguments = [
	  "--extra-vars \"ansible_python_interpreter=/usr/bin/python3 kernel.full=6.1.62-current-sunxi\"",
	  "-vv",
	  "--skip-tags", "only64,no_bananapi"
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
    destination = "../../staged_${source.name}.tgz"
    direction   = "download"
    source      = "/root/staging.tgz"
    override = {
      "orangepwn02w" = { destination = "../../staged_oragenpwn02w.tgz" }
    }
  }

  provisioner "shell" {
    inline = [
      "echo Removing staging directory from image",
      "rm -rf /root/staging /root/staging.tgz"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo ADD FEATURE compress and sha256sum the image"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo '[|}=- Job is complete. Take a deep breath. -={|]'",
      "curl -s -d 'Build ${source.name} completed' ntfy.sh/pwny_builder"
    ]
  }
}
