#!/bin/sh
# Centos 7
# DHCP networking configuration
#
# should perform configuration or exit with > 0 return code
# will be called several time until success or give up during
# Main Loop (https://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html#_main_loop)
PATH=/usr/bin:/bin:/sbin

. /lib/dracut-lib.sh

mkdir -p  /var/lib/dhclient
ip=$(ip addr | grep "inet " | grep -v "127.")
if [ -z "$ip" ]
then
    dhclient -v -timeout 60
    exit 1
else
    #some debug output
    info "resolv.conf: \n $(cat /etc/resolv.conf 2>&1)"
    info "Connecting to KMS: $(nc -v -w 1 kms.us-east-1.amazonaws.com 443 2>&1)"
    info "Connecting to metadata service: $(nc -v -w 1 169.254.169.254 80 2>&1)"
    exit 0
fi
