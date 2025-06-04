#!/bin/bash

usage() {
	echo "Usage: backup.sh [-honu] [-h] [-u user] [-n host name or ip] [-o output]"
}

RUN_LOCAL=0


while getopts "hlbo:n:u:p:" arg; do
	case $arg in
		h)
			usage
			exit
			;;
		l)
		    RUN_LOCAL=1
		    ;;
		b)
		    SAVE_BOOT=1
		    ;;
		n)
			UNIT_HOSTNAME=$OPTARG
			;;
		o)
			OUTPUT=$OPTARG
			;;
		u)
			UNIT_USERNAME=$OPTARG
			;;
		p)
		    PWN_PREFIX=$OPTARG
		    ;;
		*)
			usage
			exit 1
	esac
done


# name of the ethernet gadget interface on the host
if [[ "$RUN_LOCAL" == "1" ]] ; then
    UNIT_HOSTNAME=${UNIT_HOSTNAME:-$(hostname)}
else
    UNIT_HOSTNAME=${UNIT_HOSTNAME:-10.0.0.2}
fi

# output backup tgz file
OUTPUT=${OUTPUT:-${HOME}/Backups/${UNIT_HOSTNAME}-backup-$(date +%Y%m%d-%H%M).tgz}
# username to use for ssh
UNIT_USERNAME=${UNIT_USERNAME:-pwnagotchi}
# file prefix, default /, useful for remote mounts
PWN_PREFIX=${PWN_PREFIX:-/}

# what to backup
FILES_TO_BACKUP="root/brain.nn \
  root/brain.json \
  root/.api-report.json \
  root/.ssh \
  root/.bashrc \
  root/.profile \
  root/.vimrc \
  boot/handshakes \
  root/peers \
  root/wardriver/wardriver.db \
  root/Wall-of-Flippers/Flipper.json \
  etc/pwnagotchi/ \
  etc/hostname \
  etc/hosts \
  etc/pwngrid \
  etc/ssh/ \
  etc/default/gpsd \
  etc/systemd/system/pwn-gpsd.service \
  var/log/pwnagotchi.log \
  var/log/pwnagotchi*.gz \
  home/pi/pwnagotchi*.gz \
  home/pi/pwnagotchi.log \
  home/pi/logs/ \
  home/pi/.ssh \
  home/pi/.bashrc \
  home/pi/.profile \
  home/pwnagotchi/.profile \
  home/pwnagotchi/.bashrc \
  home/pwnagotchi/.vimrc \
  home/pwnagotchi/bin \
  home/pwnagotchi/logs \
  usr/local/share/pwnagotchi/custom-plugins/ \
  root/.api-report.json \
  root/.auto-update \
  root/.spotify_tokens \
  root/.ohc_uploads \
  root/.wigle_uploads \
  root/.wpa_sec_uploads"


if [[ "$RUN_LOCAL" == "1" ]]; then
    sudo systemctl stop bettercap pwnagotchi pwngrid-peer
    FTB=$(cd ${PWN_PREFIX} && sudo find ${FILES_TO_BACKUP} -type f)
    echo "Saving to ${OUTPUT}"
    echo "Saving files: ${FTB}"
    
    (cd ${PWN_PREFIX} && sudo tar -czf "${OUTPUT}" --checkpoint=500 -C ${PWN_PREFIX} --exclude __pycache__ --exclude \*~ -- ${FTB} )
    ls -l $OUTPUT
    if [[ "$SAVE_BOOT" ]]; then
	sudo cp $OUTPUT /boot/pwny-backup.tar.gz
    fi
else 
    echo "WTF"
    exit 2
    ping -c 1 "${UNIT_HOSTNAME}" > /dev/null 2>&1 || {
	echo "@ unit ${UNIT_HOSTNAME} can't be reached, make sure it's connected and a static IP assigned to the USB interface."
	exit 1
    }


    echo "@ stopping services on $UNIT_HOSTNAME..."
    ssh -t "${UNIT_USERNAME}@${UNIT_HOSTNAME}" "sudo systemctl stop bettercap pwnagotchi pwngrid-peer"
    echo "@ backing up $UNIT_HOSTNAME to $OUTPUT ..."
    echo ssh "${UNIT_USERNAME}@${UNIT_HOSTNAME}" "(cd ${PWN_PREFIX} && sudo find ${FILES_TO_BACKUP} -type f -print0 ) | xargs -0 sudo tar --checkpoint=500 -C ${PWN_PREFIX} --exclude __pycache__ --exclude \*~ -c"
    sleep 5
    ssh -t "${UNIT_USERNAME}@${UNIT_HOSTNAME}" "(cd ${PWN_PREFIX} && sudo find ${FILES_TO_BACKUP} -type f -print0) | xargs -0 sudo tar --checkpoint=500 -C ${PWN_PREFIX} --exclude __pycache__ --exclude \*~ -c" | gzip -9 > "$OUTPUT"
    echo "@ restarting services on $UNIT_HOSTNAME..."
    ssh -t "${UNIT_USERNAME}@${UNIT_HOSTNAME}" "sudo systemctl restart bettercap pwngrid-peer pwnagotchi"
fi # RUN_LOCAL
