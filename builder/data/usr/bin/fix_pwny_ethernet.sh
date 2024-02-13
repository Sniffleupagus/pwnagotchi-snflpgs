#!/usr/bin/bash -e

for iface in $(/sbin/ifconfig -a | egrep '^(eth|enx)' | cut -d: -f1); do
    echo "Ethernet $iface"

    if [ ! -f /etc/network/interfaces.d/${iface}-cfg ]; then
	echo "Setting up ethernet $iface for DHCP"
	cat >/etc/network/interfaces.d/${iface}-cfg <<EOF
allow-hotplug ${iface}
iface ${iface} inet dhcp
metric 18
EOF
    fi
done
