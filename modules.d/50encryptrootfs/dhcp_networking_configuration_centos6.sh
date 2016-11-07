#!/bin/sh
# Centos 6
# DHCP networking configuration
PATH=/usr/bin:/bin:/sbin

. /lib/dracut-lib.sh

mkdir -p  /var/lib/dhclient

ip=$(ip addr | grep "inet " | grep -v "127.")
if [ -z "$ip" ]
then
    info "DHCP network configuration"
    out="$(dhclient -v -sf /sbin/dhclient-script-encryptrootfs 2>&1)"
    info "DHCP network configuration output \n ${out}"
    exit 1
else
    info "DHCP network configuration ${ip}"
    #some debug output
    info "resolv.conf: \n $(cat /etc/resolv.conf 2>&1)"
    info "Connecting to KMS: $(echo "" | nc -v kms.us-east-1.amazonaws.com 443 2>&1)"
    info "Connecting to metadata service: $(echo "" | nc -v 169.254.169.254 80 2>&1)"
    exit 0
fi