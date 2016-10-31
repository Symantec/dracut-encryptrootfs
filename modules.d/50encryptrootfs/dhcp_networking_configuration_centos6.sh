#!/bin/sh
# Centos 6
# DHCP networking configuration
PATH=/usr/bin:/bin:/sbin

. /lib/dracut-lib.sh

mkdir -p  /var/lib/dhclient

while true
do
    ip=$(ip addr | grep "inet " | grep -v "127.")
    if [ -z "$ip" ]
    then
        info "DHCP network configuration"
        dhclient -v -timeout 60
    else
        break
    fi
done