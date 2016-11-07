#!/bin/sh

setup_interface() {
    ip=$new_ip_address
    mtu=$new_interface_mtu
    mask=$new_subnet_mask
    bcast=$new_broadcast_address
    gw=${new_routers%%,*}
    domain=$new_domain_name
    search=$(printf "$new_domain_search")
    namesrv=$new_domain_name_servers
    hostname=$new_host_name

    # Taken from debian dhclient-script:
    # The 576 MTU is only used for X.25 and dialup connections
    # where the admin wants low latency.  Such a low MTU can cause
    # problems with UDP traffic, among other things.  As such,
    # disallow MTUs from 576 and below by default, so that broken
    # MTUs are ignored, but higher stuff is allowed (1492, 1500, etc).
    if [ -n "$mtu" ] && [ $mtu -gt 576 ] ; then
	if ! ip link set $netif mtu $mtu ; then
            ip link set $netif down
	    ip link set $netif mtu $mtu
	    ip link set $netif up
	    wait_for_if_up $netif
	fi
    fi

    ip addr add $ip${mask:+/$mask} ${bcast:+broadcast $bcast} dev $netif

    [ -n "$gw" ] && ip route add default via $gw dev $netif

    [ -n "${search}${domain}" ] && echo "search $search $domain" > /etc/resolv.conf
    if  [ -n "$namesrv" ] ; then
	for s in $namesrv; do
	    echo nameserver $s
	done
    fi >> /etc/resolv.conf
}

PATH=$PATH:/sbin:/usr/sbin
. /lib/dracut-lib.sh

# We already need a set netif here
netif=$interface

case $reason in
    PREINIT)
	echo "dhcp: PREINIT $netif up"
	ip link set $netif up
	wait_for_if_up $netif
	;;
    BOUND)
	echo "dhcp: BOND setting $netif"
	if ! arping -q -D -c 2 -I $netif $new_ip_address ; then
	    warn "Duplicate address detected for $new_ip_address while doing dhcp. retrying"
	    exit 1
	fi
	setup_interface
	set | while read line; do
	    [ "${line#new_}" = "$line" ] && continue
	    echo "$line"
	done >/tmp/dhclient.$netif.dhcpopts
	echo online > /sys/class/net/$netif/uevent
	;;
    *) echo "dhcp: $reason";;
esac

exit 0