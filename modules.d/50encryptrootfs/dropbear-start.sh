#!/bin/sh

. /lib/dracut-lib.sh

log_file=/tmp/drop-bear.log

_info() {
    info "$*"
    _write_log $*
}

_warning() {
    warn "$*"
    _write_log $*
}

_write_log(){
    echo "$*" >> $log_file
}

#starting dropbear in case of any errors
_start_dropbear_session() {
    [ -f /tmp/dropbear.pid ] && kill -0 $(cat /tmp/dropbear.pid) 2>/dev/null || {
      _info "sshd port: ${dropbear_port}"
      for keyType in $keyTypes; do
        eval fingerprint=\$dropbear_${keyType}_fingerprint
        eval bubble=\$dropbear_${keyType}_bubble
        _info "Boot SSH ${keyType} key parameters: "
        _info "  fingerprint: ${fingerprint}"
        _info "  bubblebabble: ${bubble}"
      done

      /sbin/dropbear -E -m -s -j -k -p ${dropbear_port} -P /tmp/dropbear.pid 2>$log_file
      if [[ $? -gt 0 ]];then
        _warning 'Dropbear sshd failed to start'
        exit 1
      fi
    }
}

. /etc/encryptrootfs.conf
_start_dropbear_session
