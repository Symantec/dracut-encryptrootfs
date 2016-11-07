#!/bin/sh
#centos 6
#finished queue is not available in initqueue, so registering hook by ourselves
echo '/sbin/encryptrootfs_networking_configuration_impl.sh' > /initqueue-finished/encryptrootfs_networking_configuration.sh
