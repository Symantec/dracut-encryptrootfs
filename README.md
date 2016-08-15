# dracut-encryptrootfs
Dracut module for encryption of rootfs partition during first boot. The 
[Cryptsetup](https://gitlab.com/cryptsetup/cryptsetup)
[LUKS](https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup)
implementation is used for crypto. 

It is targeted to protect data with encryption for cases when physical 
access to disk is technically possible.

## Workflow
dracut-encryptrootfs does the following to encrypt rootfs partition.

1. During boot on `initramfs` aks early user space
    1. copying all rootfs partition content to memory 
    1. repartitioning of disk
        1. creating, formatting, labeling `label:boot` partition
        1. creating, formatting future rootfs partition
    1. generating plain text LUKS key
    1. creating and configuring LUKS volume
    1. copying back rootfs content from memory to LUKS backed partition
    1. encrypting LUKS key and storing it to `/boot/luks.key` location
1. During `init` process (:exclamation: **not implemented yet**)
    1. moving all `/boot` content to `label:boot` partition
    1. updating GRUB configuration
    1. updating MBR and re-installing boot loader 

## Installation
Module could be installed from git repo directly.

`cp -a modules.d/* /usr/lib/dracut/modules.d/`
`cp encryptrootfs.conf /etc/dracut.conf.d/`

TODO(illia): describe systemd service installation here

### Compatibility
Module is compatible with Centos 7. It uses `GRUB`, `Cryptsetup`,
`systemd` and expects `MBR` partitioning schema.

### Key management
The key management logic is pluggable and could be configured with
providing corresponding bash implementation `naive_keymanagement.sh`
could be used as example.

### Networking configuration
It is expected that LUKS key is never stored in unencrypted way on
machine and decrypted with external key management system. So network
connectivity is a critical dependency.

Another reason for networking is ability to troubleshoot dracut for
headless system where console or VNC is not an option (f.e. AWS EC2). 

The networking configuration logic could be customized with providing 
bash implementation. DHCP implementation
`dhcp_networking_configuration.sh` could be used as sample.

This script will be called until it returns `0` as part of dracut
`initqueue`

### AWS KMS integration
To integrate module with AWS Key Management System 
[simple-cloud-encrypt](https://github.com/cviecco/simple-cloud-encrypt)
utility could be used.

## Troubleshooting
To troubleshoot boot process you can follow all standard
[documentation](https://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html#_troubleshooting)
with the only difference when you don't have access to machine console
you can login via ssh using RSA key configured during module 
installation.

`ssh root@VM_HOST -p 2222`, where `2222` - default port

## Contributions

Prior to receiving information from any contributor, Symantec requires
that all contributors complete, sign, and submit Symantec Personal
Contributor Agreement (SPCA).  The purpose of the SPCA is to clearly
define the terms under which intellectual property has been
contributed to the project and thereby allow Symantec to defend the
project should there be a legal dispute regarding the software at some
future time. A signed SPCA is required to be on file before an
individual is given commit privileges to the Symantec open source
project.  Please note that the privilege to commit to the project is
conditional and may be revoked by Symantec.

If you are employed by a corporation, a Symantec Corporate Contributor
Agreement (SCCA) is also required before you may contribute to the
project.  If you are employed by a company, you may have signed an
employment agreement that assigns intellectual property ownership in
certain of your ideas or code to your company.  We require a SCCA to
make sure that the intellectual property in your contribution is
clearly contributed to the Symantec open source project, even if that
intellectual property had previously been assigned by you.

Please complete the SPCA and, if required, the SCCA and return to
Symantec at:

Symantec Corporation
Legal Department
Attention:  Product Legal Support Team
350 Ellis Street
Mountain View, CA 94043

Please be sure to keep a signed copy for your records.

## LICENSE

Copyright 2015 Symantec Corporation.

Licensed under the Apache License, Version 2.0 (the “License”); you
may not use this file except in compliance with the License.

You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by
applicable law or agreed to in writing, software distributed under the
License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for
the specific language governing permissions and limitations under the
License.
