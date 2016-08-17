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

    #dropbear-start.sh
    dracut_install dropbear

    #encryptrootfs.sh
    dracut_install awk
    dracut_install grep
    dracut_install fdisk
    dracut_install sfdisk
    dracut_install parted
    dracut_install mkfs.$boot_partition_file_system
    dracut_install mkfs.$rootfs_partition_file_system
    dracut_install e2label
    dracut_install blkid
    dracut_install insmod


    #debug and troubleshooting toolset
    if [  "${install_debug_deps}" == "true" ];then
        dinfo "Installing debug dependencies '${debug_deps}'"
        _install_impl_dependencies "${debug_deps}"
    fi

}

_install_impl_dependencies(){
    dependencies=$1
    for dep in $dependencies; do
        dinfo "Installing $dep"
        dracut_install $dep
    done
}

_lookup_implementation(){
    path=$1
    moddir=$2
    impl_path=""
    if [  -e $path ]
    then
        impl_path=$path
    else
        if [  -e $moddir/$path ]
        then
            impl_path=$moddir/$path
        else
            derror "Implementation was not found by path "$path" as well as in module directory "$moddir
            exit 1
        fi
    fi
    echo $impl_path
}

install() {
      #some initialization and validation
      [[ -z "${dropbear_port}" ]] && dropbear_port=222
      [[ -z "${dropbear_acl}" ]] && dropbear_acl=""
      [[ -z "${encrypted_keyfile_path}" ]] && encrypted_keyfile_path="luks.key"
      [[ -z "${decrypted_keyfile_path}" ]] && decrypted_keyfile_path="/tmp/keyfile.key"
      [[ -z "${boot_partition_size}" ]] && boot_partition_size="200"
      [[ -z "${boot_partition_file_system}" ]] && boot_partition_file_system="ext3"
      [[ -z "${rootfs_partition_file_system}" ]] && rootfs_partition_file_system="ext3"
      [[ -z "${boot_partition_label}" ]] && boot_partition_label="boot"
      [[ -z "${key_management_implementation}" ]] && key_management_implementation="naive_keymanagement.sh"
      [[ -z "${networking_configuration_implementation}" ]] && networking_configuration_implementation="dhcp_networking_configuration.sh"
      [[ -z "${install_debug_deps}" ]] && install_debug_deps="false"
      [[ -z "${debug_deps}" ]] && debug_deps=""

      if [[ -z "${disk}" ]];then
        derror "'disk' parameter should be defined in config."
        return 1
      fi

      if [[ -z "${root_partition}" ]];then
        derror "'root_partition' parameter should be defined in config."
        return 1
      fi

      local tmpDir=$(mktemp -d --tmpdir encryptrootfs.XXXX)
      local dropbearAcl="${tmpDir}/authorized_keys"
      echo "${dropbear_acl}" > $dropbearAcl

      local keyTypes="rsa ecdsa"
      local genConf="${tmpDir}/encryptrootfs.conf"
      local installConf="/etc/encryptrootfs.conf"

      #start writing the conf for initramfs include
      echo -e "#!/bin/bash\n\n" > $genConf
      echo "keyTypes='${keyTypes}'" >> $genConf
      echo "dropbear_port='${dropbear_port}'" >> $genConf

      #go over different encryption key types
      for keyType in $keyTypes; do
        eval state=\$dropbear_${keyType}_key
        local msgKeyType=$(echo "$keyType" | tr '[:lower:]' '[:upper:]')

        [[ -z "$state" ]] && state=GENERATE

        local osshKey="${tmpDir}/${keyType}.ossh"
        local dropbearKey="${tmpDir}/${keyType}.dropbear"
        local installKey="/etc/dropbear/dropbear_${keyType}_host_key"

        case ${state} in
          GENERATE )
            ssh-keygen -t $keyType -f $osshKey -q -N "" || {
              derror "SSH ${msgKeyType} key creation failed"
              rm -rf "$tmpDir"
              return 1
            }

            ;;
          SYSTEM )
            local sysKey=/etc/ssh/ssh_host_${keyType}_key
            [[ -f ${sysKey} ]] || {
              derror "Cannot locate a system SSH ${msgKeyType} host key in ${sysKey}"
              derror "Start OpenSSH for the first time or use ssh-keygen to generate one"
              return 1
            }

            cp $sysKey $osshKey
            cp ${sysKey}.pub ${osshKey}.pub

            ;;
          * )
            [[ -f ${state} ]] || {
              derror "Cannot locate a system SSH ${msgKeyType} host key in ${state}"
              derror "Please use ssh-keygen to generate this key"
              return 1
            }

            cp $state $osshKey
            cp ${state}.pub ${osshKey}.pub
            ;;
        esac

        #convert the keys from openssh to dropbear format
        dropbearconvert openssh dropbear $osshKey $dropbearKey > /dev/null 2>&1 || {
          derror "dropbearconvert for ${msgKeyType} key failed"
          rm -rf "$tmpDir"
          return 1
        }

        #install and show some information
        local keyFingerprint=$(ssh-keygen -l -f "${osshKey}")
        local keyBubble=$(ssh-keygen -B -f "${osshKey}")
        dinfo "Boot SSH ${msgKeyType} key parameters: "
        dinfo "  fingerprint: ${keyFingerprint}"
        dinfo "  bubblebabble: ${keyBubble}"
        inst $dropbearKey $installKey

        echo "dropbear_${keyType}_fingerprint='$keyFingerprint'" >> $genConf
        echo "dropbear_${keyType}_bubble='$keyBubble'" >> $genConf

      done

      #key pathes
      echo "encrypted_keyfile_path='${encrypted_keyfile_path}'" >> $genConf
      echo "decrypted_keyfile_path='${decrypted_keyfile_path}'" >> $genConf

      echo "boot_partition_size='${boot_partition_size}'" >> $genConf

      echo "disk='${disk}'" >> $genConf
      echo "root_partition='${root_partition}'" >> $genConf
      echo "boot_partition_file_system='${boot_partition_file_system}'" >> $genConf
      echo "rootfs_partition_file_system='${rootfs_partition_file_system}'" >> $genConf
      echo "boot_partition_label='${boot_partition_label}'" >> $genConf

      inst $genConf $installConf


      #installing networking configuration implementation
      dinfo "Installing network configuration dependencies '${networking_configuration_dependencies}'"
      _install_impl_dependencies $networking_configuration_dependencies
      impl_path=$(_lookup_implementation $networking_configuration_implementation $moddir)
      dinfo "Network configuration implementation ${impl_path} is used"

      #making sure that it is executable
      cp $impl_path $tmpDir/network.sh
      chmod 744 $tmpDir/network.sh
      inst $tmpDir/network.sh /sbin/encryptrootfs_networking_configuration_impl.sh

      #installing actual keymanagement implementation
      impl_path=$(_lookup_implementation $key_management_implementation $moddir)
      dinfo "Key management implementation ${impl_path} is used"
      source $impl_path
      key_management_deps=$(key_management_dependencies)
      dinfo "Installing key management configuration dependencies '${key_management_deps}'"
      _install_impl_dependencies $key_management_deps
      inst_simple $impl_path /sbin/encryptrootfs_key_management_impl.sh

      inst_hook cmdline 20 "$moddir/encryptrootfs-init.sh"
      inst_hook pre-mount 01 "$moddir/dropbear-start.sh"
      inst_hook pre-mount 99 "$moddir/encryptrootfs.sh"

      dinfo "authorized_keys: ${dropbear_acl}"
      inst "${dropbearAcl}" /root/.ssh/authorized_keys

      #cleanup
      rm -rf $tmpDir

      _install_depencencies
      #removing systemd generator as far as it performs file system check on any operation with rootfs partition
      #more information about systemd.generator http://bit.ly/2aWWCmy
      sed -i '/systemd-fstab-generator/d' /usr/lib/dracut/modules.d/98systemd/module-setup.sh
}