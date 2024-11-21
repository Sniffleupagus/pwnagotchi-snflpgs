#!/usr/bin/bash -e
#
# Set up monitor device in config file and pwnlib
#
# If you want to use a device other than the default,
# specify its "phy" number.  You can find that by running
# this command in a shell:
#
#    /sbin/iw dev
#
# Look for the device you want, and find the "phy#" header
# Then pass that number to this program. For example, if your
# device shows up as phy#2, you would run:
#
#  fix_pwny_iface.sh 2
#

export PWNY_BOARD=$(cat /proc/device-tree/model | tr -d '\0')

if [[ ( "${PWNY_BOARD}" == "BananaPi BPI-M4-Zero v2" ) || ( "${PWNY_BOARD}" == "Raspberry Pi"* ) ]]; then
    # nexmon devices use these standard names for pwnagotchi
    wifidev="wlan0"
    mondev="wlan0mon"
else
    # try to figure it out dynamically
    # use built in device, unless another number specified on command line
    phy=${1:-0}

    # stop pwnagotchi and monitor device if they are running
    mondev=$(/sbin/iw dev | grep -B 7 -A 7 "type monitor" | grep -A 7 phy\# | grep Interface | cut  -d ' ' -f2)
    
    if [ "$mondev" ]; then
	echo "Stopping pwnagotchi services"
	systemctl stop pwnagotchi bettercap pwngrid-peer
	
	airmon-ng stop $mondev
    fi

    # locate the wifi device of interest ($phy)
    wifidev=$(/sbin/iw dev | grep -A 7 phy\#$phy | grep Interface | cut  -d ' ' -f2 | head)

    if [ "$wifidev" ]; then
	echo "Found wifi device '$wifidev'"
    else
	echo "No device found for phy#$phy"
	exit
    fi

    # try to enable monitor mode
    airmon-ng start $wifidev

    # locate the monitor mode device
    mondev=$(/sbin/iw dev | grep -B 7 -A 7 "type monitor" | grep -A 7 phy\#$phy | grep Interface | cut  -d ' ' -f2)

    if [ "$mondev" ]; then
	echo "Found monitor device $mondev"
	airmon-ng stop $mondev
    else
	echo "No device found for phy#$phy"
	echo "Pwnagotchi will probably need manual intervention to work"
	exit
    fi
fi

if [ "$mondev" ]; then
    for conf in /etc/pwnagotchi/config.toml; do

	if grep -q main.iface $conf ; then
	    defdev=$(grep iface $conf | cut -d \" -f 2)
	    if [ "$mondev" != "$defdev" ]; then
		echo "Config says $defdev, but the device says $mondev"

		# my bananapi device has same name in monitor mode as not

		sed -i.bak -e "s/^main.iface = \"$defdev\"/main.iface = \"$mondev\"/" $conf
	    else
		echo "$conf already set for $mondev"
	    fi
	else
	    echo "adding interface to $conf"
            echo "main.iface = \"$mondev\"" >>$conf
	fi
    done
fi

if [ "$wifidev" ]; then
    # set WIFI device in pwnlib
    echo updating pwnlib for phy$phy
    sudo sed -i.bak -e "s/^#*PWNY_EXT_WLAN=\".*\"/PWNY_EXT_WLAN=\"$wifidev\"/" /usr/bin/pwnlib

    NETWORKMGR_CONF="/etc/NetworkManager/NetworkManager.conf"
    if ! grep '\[keyfile\]' $NETWORKMGR_CONF; then
	echo >>$NETWORKMGR_CONF
	echo '[keyfile]' >>$NETWORKMGR_CONF
    fi
    if ! grep "face-name:$wifidev" $NETWORKMGR_CONF; then
	echo "Setting NetworkManager to ignore $wifidev"
	sed -i "/\[keyfile\]/a\
       	unmanaged-devices=interface-name:$wifidev" $NETWORKMGR_CONF
    fi

    systemctl reload NetworkManager
fi
