#!/bin/sh
#Installs dracut module in Centos7
check() {
    require_binaries dropbear || return 1
    return 0
}

depends() {
    echo network crypt
    return 0
}

installkernel(){
    hostonly='' instmods "dm-crypt"
}

_install_depencencies() {

    #dropbear-start.sh dependencies
    dracut_install dropbear

    #encryptrootfs.sh dependencies
    dracut_install awk
    dracut_install grep
    dracut_install fdisk
    dracut_install sfdisk
    dracut_install parted
    dracut_install mkfs."$boot_partition_file_system"
    dracut_install mkfs."$rootfs_partition_file_system"
    dracut_install e2label
    dracut_install blkid
    dracut_install insmod


    #debug and troubleshooting toolset
    if [  "${install_debug_deps}" = "true" ];then
        dinfo "Installing debug dependencies '${debug_deps}'"
        _install_impl_dependencies "${debug_deps}"
    fi

}

_install_impl_dependencies(){
    dependencies=$1
    for dep in $dependencies; do
        dinfo "Installing $dep"
        dracut_install "$dep"
    done
}

_lookup_implementation(){
    path=$1
    moddir=$2
    impl_path=""
    if [  -e "$path" ]
    then
        impl_path=$path
    else
        if [  -e "$moddir/$path" ]
        then
            impl_path="$moddir/$path"
        else
            derror "Implementation was not found by path $path as well as in module directory $moddir"
            exit 1
        fi
    fi
    echo "$impl_path"
}

_check_linux_distrub(){
    if [ -x /usr/bin/lsb_release ] ; then
        OS="$(lsb_release -s -i | tr '[:lower:]' '[:upper:]')"
        if [ "$OS" = "centos" ] ; then
            OSRELEASE="$(lsb_release -s -r | sed -e 's/\..*//')"
        else
            OSRELEASE="$(lsb_release -s -c)"
        fi
    elif [ -f /etc/redhat-release ] ; then
        OSRELEASE="$(awk '{print $4}' /etc/redhat-release | sed -e 's/\..*//')"
        OS="$(awk '{print tolower($1)}' /etc/redhat-release)"
    fi

    if [ -z "${OS}" ] || [ -z "${OSRELEASE}" ] ; then
         echo "Can't identify OS. Delected values OS=${OS} OSRELEASE=${OSRELEASE}"
         exit 1
    fi
}


install() {
      _check_linux_distrub

      #some initialization and validation
      [ -z "${dropbear_port}" ] && dropbear_port=222
      [ -z "${dropbear_acl}" ] && dropbear_acl=""
      [ -z "${encrypted_keyfile_path}" ] && encrypted_keyfile_path="luks.key"
      [ -z "${decrypted_keyfile_path}" ] && decrypted_keyfile_path="/tmp/keyfile.key"
      [ -z "${boot_partition_size}" ] && boot_partition_size="200"
      [ -z "${boot_partition_file_system}" ] && boot_partition_file_system="ext3"
      [ -z "${rootfs_partition_file_system}" ] && rootfs_partition_file_system="ext3"
      [ -z "${boot_partition_label}" ] && boot_partition_label="boot"
      [ -z "${key_management_implementation}" ] && key_management_implementation="naive_keymanagement.sh"
      [ -z "${networking_configuration_implementation}" ] && networking_configuration_implementation="dhcp_networking_configuration.sh"
      [ -z "${pause_on_error}" ] && pause_on_error=10
      [ -z "${install_debug_deps}" ] && install_debug_deps="false"
      [ -z "${debug_deps}" ] && debug_deps=""


      if [ -z "${disk}" ];then
        derror "'disk' parameter should be defined in config."
        return 1
      fi

      if [ -z "${root_partition}" ];then
        derror "'root_partition' parameter should be defined in config."
        return 1
      fi

      tmpDir=$(mktemp -d --tmpdir encryptrootfs.XXXX)
      dropbearAcl="${tmpDir}/authorized_keys"
      echo "${dropbear_acl}" > "$dropbearAcl"

      keyTypes="rsa ecdsa"
      genConf="${tmpDir}/encryptrootfs.conf"
      installConf="/etc/encryptrootfs.conf"

      #start writing the conf for initramfs include
      printf "#!/bin/sh\n\n" > "$genConf"
      echo "keyTypes='${keyTypes}'" >> "$genConf"
      echo "dropbear_port='${dropbear_port}'" >> "$genConf"

      #go over different encryption key types
      for keyType in $keyTypes; do
        dropbearKey="${tmpDir}/${keyType}.dropbear"
        installKey="/etc/dropbear/dropbear_${keyType}_host_key"

        dropbearkey -t "$keyType" -f "$dropbearKey"
        inst "$dropbearKey" "$installKey"

        echo "dropbear_${keyType}_fingerprint='$keyFingerprint'" >> "$genConf"
        echo "dropbear_${keyType}_bubble='$keyBubble'" >> "$genConf"
      done

      {
          echo "encrypted_keyfile_path='${encrypted_keyfile_path}'"
          echo "decrypted_keyfile_path='${decrypted_keyfile_path}'"
          echo "boot_partition_size='${boot_partition_size}'"
          echo "disk='${disk}'"
          echo "root_partition='${root_partition}'"
          echo "boot_partition_file_system='${boot_partition_file_system}'"
          echo "rootfs_partition_file_system='${rootfs_partition_file_system}'"
          echo "boot_partition_label='${boot_partition_label}'"
          echo "pause_on_error='${pause_on_error}'"
      } >> "$genConf"

      inst "$genConf" "$installConf"


      #installing networking configuration implementation
      dinfo "Installing network configuration dependencies '${networking_configuration_dependencies}'"
      _install_impl_dependencies "$networking_configuration_dependencies"
      impl_path=$(_lookup_implementation "$networking_configuration_implementation" "$moddir")
      dinfo "Network configuration implementation ${impl_path} is used"

      #making sure that it is executable
      cp "$impl_path" "$tmpDir/network.sh"
      chmod 744 "$tmpDir/network.sh"
      inst "$tmpDir/network.sh" /sbin/encryptrootfs_networking_configuration_impl.sh

      #installing actual keymanagement implementation
      impl_path=$(_lookup_implementation "$key_management_implementation" "$moddir")
      dinfo "Key management implementation ${impl_path} is used"
      . "$impl_path"
      key_management_deps=$(key_management_dependencies)
      dinfo "Installing key management configuration dependencies '${key_management_deps}'"
      _install_impl_dependencies "$key_management_deps"
      inst_simple "$impl_path" /sbin/encryptrootfs_key_management_impl.sh

      inst_hook cmdline 20 "$moddir/encryptrootfs-init-$OS$OSRELEASE.sh"
      inst_hook pre-mount 01 "$moddir/dropbear-start.sh"
      inst_hook pre-mount 99 "$moddir/encryptrootfs.sh"

      dinfo "authorized_keys: ${dropbear_acl}"
      inst "${dropbearAcl}" /root/.ssh/authorized_keys

      #TLS certificates
      dinfo "Installing TLS certificates"
      inst /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
      inst /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt

      #cleanup
      rm -rf "$tmpDir"

      _install_depencencies

      if [  "$OS$OSRELEASE" = "centos7" ];then
        #removing systemd generator as far as it performs file system check on any operation with rootfs partition
        #more information about systemd.generator http://bit.ly/2aWWCmy
        sed -i '/systemd-fstab-generator/d' /usr/lib/dracut/modules.d/98systemd/module-setup.sh
        sed -i '/dracut-rootfs-generator/d' /usr/lib/dracut/modules.d/98systemd/module-setup.sh
      fi

}
