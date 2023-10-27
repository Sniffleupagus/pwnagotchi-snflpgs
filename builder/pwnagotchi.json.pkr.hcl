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
  output_filename   = "../../base_raspios-bullseye-armhf.img"
  qemu_args         = ["-cpu", "arm1176", "-r", "6.1.21+"]
  qemu_binary       = "qemu-arm-static"
  target_image_size = 6368709120
}

source "arm-image" "base64-image" {
  iso_checksum      = "file:https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz.sha256"
  iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
  output_filename   = "/root/base_raspios-bullseye-aarch64.img.new"
  qemu_binary       = "qemu-aarch64-static"
  target_image_size = 6368709120
}

source "arm-image" "pwnagotchi" {
  iso_checksum      = "file:/root/base_raspios-bullseye-armhf.img.xz.sha256"
  iso_url           = "/root/base_raspios-bullseye-armhf.img.xz"
  output_filename   = "/root/pwnagotchi-${var.pwn_version}-armhf.img"
  qemu_args         = ["-cpu", "arm1176"]
  qemu_binary       = "qemu-arm-static"
  target_image_size = 9368709120
}

source "arm-image" "pwnagotchi64" {
  iso_checksum      = "file:https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz.sha256"
  iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
  output_filename   = "/root/pwnagotchi-${var.pwn_version}-aarch64.img"
  qemu_binary       = "qemu-aarch64-static"
  target_image_size = 9368709120
}

build {
  sources = [
    "source.arm-image.base64-image",
    "source.arm-image.pwnagotchi",
    "source.arm-image.pwnagotchi64"
  ]

  provisioner "file" {
    destination = "/root/staging/"
    source      = "../../staging/"
  }

  provisioner "shell" {
    inline = [
      "cd /root/staging/bin",
      "chmod a+x *",
      "cp * /usr/local/bin"
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
  }

  provisioner "ansible-local" {
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${var.pwn_version} PWN_HOSTNAME=${var.pwn_hostname} ansible-playbook"
    extra_arguments = ["--extra-vars \"ansible_python_interpreter=/usr/bin/python3\"", "-vv" ]
    playbook_dir    = "../builder/"
    playbook_file   = "../builder/pwnagotchi.yml"
    override = {
      "*.base-image" = { only = "untagged,base,only32" }
      "*.base64-image" = { only = "untagged,base,onl64" }
      "*.pwnagotchi" = {
	only = "untagged,pwnagotchi,only32"
      }
      "*.pwnagotchi64" = {
	only = "untagged,base,pwnagotchi64,only64"
      }
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
    destination = "../../"
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
      "echo Unpacking staged artifacts to 'incoming' directory",
      "mkdir -p ../../incoming",
      "tar -C ../../incoming/ --overwrite -xvzf ../../staging.tgz",
      "rm ../../staging.tgz",
      "chmod -R a+rwX ../../incoming"
    ]
  }
}
