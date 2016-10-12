#!/bin/sh

. /lib/dracut-lib.sh

log_file=/tmp/dropbear.log

_info() {
    info "$*"
    _write_log "$*"
}

_warning() {
    warn "$*"
    _write_log "$*"
}

_write_log(){
    echo "$*" >> $log_file
}

#starting dropbear in case of any errors
_start_dropbear_session() {
      _info "sshd port: ${dropbear_port}"

      #/etc/passwd is not correct in centos 6
      echo "root:x:0:0:root:/root:/bin/sh" > /etc/passwd
      /usr/sbin/dropbear -E -m -s -j -k -p "$dropbear_port" -P /tmp/dropbear.pid 2>$log_file
      if [ $? -gt 0 ];then
        _warning 'Dropbear sshd failed to start'
        exit 1
      fi
}

. /etc/encryptrootfs.conf
_start_dropbear_session
