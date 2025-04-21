#!/bin/sh -e
#
# pwnagotchi_first_boot.sh
#
# used to be rc.local.FIRSTRUN, but now run from pwnagotch-setup.service
#

# pwnagotchi first run script
echo "======"
echo "Pwnagotchi customization in 10 seconds. ^C to stop"

# find a working LED
PWNY_LED=led0
for l in led0 ACT "red:status"; do
    if [ -e "/sys/class/leds/$l/brightness" ]; then
        PWNY_LED=$l
        break
    fi
done

# well ... it blinks the led
blink_led() {
  for i in $(seq 1 "$1"); do
    echo 0 >/sys/class/leds/${PWNY_LED}/brightness
    sleep 0.3
    echo 1 >/sys/class/leds/${PWNY_LED}/brightness
    sleep 0.3
  done
  echo 0 >/sys/class/leds/${PWNY_LED}/brightness
  sleep 0.3
}
blink_led 6
sleep 2
blink_led 9
sleep 2
echo "Here goes"


ARMBIAN_ENV=/boot/armbianEnv.txt
EXTLINUX_CONF=/boot/extlinux/extlinux.conf

export PWNY_BOARD=$(cat /proc/device-tree/model)
if [ "${PWNY_BOARD}" = "BananaPi BPI-M4-Zero" ]; then
    if ! ls -d /sys/class/net/w* ; then
	# no wifi, so maybe it is a bananapim4zero v2
	#systemctl enable reload_nexmon.service
	if [ -f ${ARMBIAN_ENV} ]; then
            if ! grep '^overlays=.*bananapi-m4-sdio-wifi-bt' ${ARMBIAN_ENV}; then
		# enable the overlay
		sed -i.ORIG '/^overlays=.*bananapi-m4-pg-15/s/^/#/' ${ARMBIAN_ENV}
		sed -i '/^# *overlays=bananapi-m4-sdio/s/^# *//' ${ARMBIAN_ENV}

		# no working bluetooth on V2, so disable wof.service
		systemctl disable wof.service || true

		sync
		echo "Rebooting to install wifi/bt overlay..."
		sleep 10
		reboot
	    fi
	elif [ -f ${EXTLINUX_CONF} ]; then
	    if ! grep '^\tfdtoverlays .*bananapi-m4-sdio-wifi-bt' ${EXTLINUX_CONF}; then
		sed -i.ORIG '/^\t*fdtoverlays.*h616-i2c4/s/fdtoverlays/#fdtoverlays/' ${EXTLINUX_CONF}
		sed -i '/#fdtoverlays.*bananapi-m4-sdio-wifi-bt/s#fdtoverlays/fdtoverlays/' ${EXTLINUX_CONF}

		sync
		echo "Rebooting to install wifi/bt overlay..."
		sleep 10
		reboot
	    fi
        fi
    fi
fi

# set up usb0 through NetworkManager
echo "+++ Configuring RNDIS interface with NetworkManager"
nmcli --wait 10 dev con usb0 || true
nmcli con mod usb0 ipv4.method manual ipv4.address 10.0.0.2/24 ipv4.gateway 10.0.0.1 ipv4.route-metric 950 || true
nmcli dev set usb0 autoconnect yes || true
nmcli dev mod usb0 IPV4.ADDRESS 10.0.0.2/24 IPV4.GATEWAY 10.0.0.1

systemctl stop bettercap pwngrid-peer pwnagotchi

# restore a tarball backup file
if [ -f /boot/pwny-backup.tar.gz ]; then
    exclude_boot=""
    if [ ! -f /boot/config.txt ]; then
	exclude_boot="--exclude boot/{config.txt,cmdline.txt}"
    fi
    echo "+++ Restoring pwny from backup"
    tar -C / -h --keep-directory-symlink -xzf /boot/pwny-backup.tar.gz ${exclude_boot} --exclude root/handshakes --exclude etc/pwnagotchi && true
    # overwrite files in /etc/pwnagotchi
    tar -C / -xzvf /boot/pwny-backup.tar.gz etc/pwnagotchi
    echo "+++ quietly extracting handshakes to /root/handshakes"
    tar -C /root --strip-components 1 --dereference --keep-directory-symlink -xzf /boot/pwny-backup.tar.gz root/handshakes || \
    tar -C /root --strip-components 1 --dereference --keep-directory-symlink -xzf /boot/pwny-backup.tar.gz boot/handshakes
    echo ">>>---> Moving backup to pwnagotchi home directory"
    mkdir -p -m=755 /home/pwnagotchi/Backups
    mv /boot/pwny-backup.tar.gz  /home/pwnagotchi/Backups/pwny-backup-STARTUP.tar.gz
    chown -R pwnagotchi:pwnagotchi /home/pwnagotchi/Backups
fi

/usr/bin/fix_pwny_ethernet.sh
/usr/bin/fix_pwny_iface.sh

echo "+++ Setting up pwnagotchi system services"
systemctl enable bettercap pwngrid-peer pwnagotchi

# disable setup script from running this again
systemctl disable pwnmagotchi-setup

systemctl restart bettercap pwngrid-peer pwnagotchi

nmcli conn up usb0
exit 0
