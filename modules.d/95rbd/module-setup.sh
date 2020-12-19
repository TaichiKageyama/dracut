#!/bin/bash

# How to use rbdroot
#
# Prepare OSD pool
#  # ceph osd pool create rbd-boot 64,64 ssd-rule
#  # ceph auth get-or-create cient.rbd-boot mon 'profile=rbd' osd 'profile=rbd, pool=rbd-bood'
# Prepare Root Disk
#  # cd /tmp
#  # dd if=/dev/zero of=/tmp/el7.img bs=4M count=2042
#  # mkfs.xfs /tmp/el7.img
#  # setenforce 0
#  # mount /tmp/el7.img /mnt/img
#  # yum groupinstall "Minimal Install" --releasever=7.9.2009  --installroot=/mnt/img
#  # cp -rp /lib/modules/xxx.el7.yy /mnt/img/lib/modules/.
#
# Note. Make sure SELinux is disabled here before you do chroot
#       Otherwise, passwd fails with the following error
#         "passwd: Authentication token manipulation error".
#
#  # chroot /mnt/img
#  > passwd
#  > sed -i "s/^SELINUX=.*/SELINUX=disabled/g" /etc/selinux/config
#  > mkdir /root/.ssh; chmod 700 /root/.ssh; touch /root/.ssh/authorized_keys
#  > chmod 600 /root/.ssh/authorized_keys;
#  > vi /root/.ssh/authorized_keys
#  > exit
#  # rbd import /tmp/el7.img rbdboot/rhel7.root
#  # rbd feature disable rbdboot/rhel7.root deep-flatten,fast-diff,object-map
#
# Prepare initramfs
#  # yum install git dracut
#  # cd /usr/lib/dracut/modules.d
#  # git init; git add .; git commit -a "initial commit"; git pull xxxx
#  # vi 95rbd/rbdroot.sh
#  RBD_KEY="xxxxxxxxxxxxxxxxxxx=="
#  # yum install kernel-x.y.z
#  # dracut -m "rbd network base" -H /tmp/initramfs-x.y.z-rbdboot.img x.y.z
#  # chmod 444 /tmp/initramfs-x.y.z-rbdboot.img
# Boot
#  initrd=xxx root=rbd:mon1,mon2,mon3:id/secret:rbdpool/img::xfs:default
#  net.ifnames=0 ip=eth0:dhcp console=ttyS0,115200n8 rw
#  elevator=cfq rootwait init=/lib/systemd/systemd

check()
{
    modprobe -n rbd >/dev/null 2>&1 && return 255
    return 1
}

depends()
{
    echo network rootfs-block bash shutdown biosdevname
}

installkernel()
{
    # instmods <kernelmodule> [ <kernelmodule> … ]
    #   instmods will not install the kernel module,
    #   if $hostonly is set and the kernel module is not currently needed
    #   by any /sys/…/uevent MODALIAS. To install a kernel module
    #   regardless of the hostonly mode use the form:
    #    hostonly='' instmods <kernelmodule>
    hostonly='' instmods virtio_pci
    hostonly='' instmods rbd
    hostonly='' instmods ext4 xfs
    hostonly='' instmods virtio_net tg3 ixgbe
    # Note: instmods just install kernel modules to resolve dependencies
    #  You need to load them if needed
}

install()
{
    # Try to use haveged if entropy is not enough
    #      yum install epel-release
    #      yum install haveged
    #inst_multiple haveged pkill

    # modules.d/40network/netroot.sh kicks $hookdir/cmdline/90*.sh
    # after unset rootok
    inst_hook cmdline 90 "$moddir/parse-rbdroot.sh"
    inst_script "$moddir/rbdroot.sh" "/sbin/rbdroot"
}

