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
  iso_checksum      = "file:https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz.sha256"
  iso_url           = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz"
  output_filename   = "/root/base_raspios-bullseye-armhf.img"
  qemu_args         = ["-cpu", "arm1176"]
  image_arch        = "arm"
  target_image_size = 9368709120
}

source "arm-image" "base64-image" {
  iso_checksum      = "file:https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz.sha256"
  iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
  output_filename   = "/root/base_raspios-bullseye-aarch64.img"
  image_arch        = "arm64"
  target_image_size = 9368709120
}

source "arm-image" "pwnagotchi" {
  iso_checksum      = "file:/root/base_raspios-bullseye-armhf.img.xz.sha256"
  iso_url           = "file:/root/base_raspios-bullseye-armhf.img.xz"
  output_filename   = "/root/pwnagotchi-${var.pwn_version}-armhf.img"
  qemu_args         = ["-cpu", "arm1176"]
  image_arch        = "arm"
  target_image_size = 9368709120
}

source "arm-image" "pwnagotchi64" {
  iso_checksum      = "file:/root/base_raspios-bullseye-aarch64.img.xz.sha256"
  iso_url           = "file:/root/base_raspios-bullseye-aarch64.img.xz"
  output_filename   = "/root/pwnagotchi-${var.pwn_version}-aarch64.img"
  image_arch        = "arm64"
  target_image_size = 9368709120
}

source "arm-image" "orangepwn02w" {
  iso_checksum      = "file:/vagrant_data/Orangepizero2w_1.0.0_debian_bookworm_server_linux6.1.31.img.sha"
  iso_url           = "file:/vagrant_data/Orangepizero2w_1.0.0_debian_bookworm_server_linux6.1.31.img"
  image_type        = "armbian"
  output_filename   = "/root/pwnagotchi-${var.pwn_version}-orangepi02w.img"
  qemu_args         = ["-r", "6.1.31-sun50iw9"]
  image_arch        = "arm64"
  target_image_size = 9368709120
}

build {
  sources = [
    "source.arm-image.base-image",
    "source.arm-image.base64-image",
    "source.arm-image.pwnagotchi",
    "source.arm-image.pwnagotchi64",
    "source.arm-image.orangepwn02w"
  ]

  provisioner "file" {
    destination = "/root/staging/"
    source      = "../../staging/"
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
    inline = [
      "echo Install kernel headers",
      "apt-get install -y raspberrypi-kernel-headers",
      "apt-mark hold raspberrypi-kernel raspberrypi-kernel-headers",
      "echo '>>>-----> APT UPDATE <-----<<<'",
      "apt-get -y --allow-releaseinfo-change update",
      "echo '==>-----> APT UPGRADE <-----<=='",
      "apt-get -y upgrade",
      "echo '###======]> INSTALLING ANSIBLE <[=====###'",
      "apt install -y ansible"
    ]
    override = {
      "orangepwn02w" = {
	inline = [
	  "echo Skip install kernel headers",
	  "#apt install linux-headers-$(uname -r)",
	  "echo '>>>-----> APT UPDATE <-----<<<'",
	  "apt-get -y --allow-releaseinfo-change update",
	  "echo '==>-----> APT UPGRADE on opi later <-----<=='",
	  "#apt-get -y upgrade",
	  "echo '###======]> INSTALLING ANSIBLE <[=====###'",
	  "apt install -y ansible"
	  "curl -s -d '${source.name} ansible ready' ntfy.sh/pwny_builder"
	]
      }
    }
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
