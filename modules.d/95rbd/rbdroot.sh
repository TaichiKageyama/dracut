#!/bin/bash

# This script is called from netroot.sh
# The file name should be rbdroot.sh
# Because the following rule is defined in netroot.sh
#   handler=${netroot%%:*}
#   handler=${handler%%4}
#   handler=$(command -v ${handler}root)
#   "$handler" "$netif" "$netroot" "$NEWROOT"

[ -z "$1" ] && exit 1
export RBD_DHCP_NETIF="$1"
[ -z "$2" ] && exit 1
export RBD_ROOT_PATH="$2"
[ -z "$3" ] && exit 1
export RBD_MNT_PATH="$3"

export RBD_MONS RBD_ID RBD_KEY
export RBD_POOL RBD_IMG RBD_SNAP RBD_PART RBD_FS RBD_OPTS

rbd_map()
{
    local param="$1" rbd_bus dev rbd_magic
    modprobe rbd
    rbd_map_parse "$param"
    # The kernel will reject writes to add if add_single_major exists
    if [ -e /sys/bus/rbd/add_single_major ]; then
        rbd_bus=/sys/bus/rbd/add_single_major
    elif [ -e /sys/bus/rbd/add ]; then
        rbd_bus=/sys/bus/rbd/add
    else
        warn "ERROR: /sys/bus/rbd/add does not exist"
        exit 1
    fi

    rbd_magic="${RBD_MONS} name=${RBD_ID},secret=${RBD_KEY}"
    rbd_magic="$rbd_magic ${RBD_POOL} ${RBD_IMG} ${RBD_SNAP}"
    # Tell the kernel rbd client to map the block device
    echo "$rbd_magic" > $rbd_bus

    # Figure out where the block device appeared
    dev=$(ls /dev/rbd* | grep '/dev/rbd[0-9]*$' | awk 'END{print}')
    # Add partition Number if needed
    if [ "$RBD_PART" != "" ]; then
        dev=${dev}p${RBD_PART}
    fi
    ln -s $dev /dev/root

    type write_fs_tab >/dev/null 2>&1 || . /lib/fs-lib.sh
    write_fs_tab /dev/root "$RBD_FS" "$RBD_OPTS"
}

# <mons>:<id>/<key>:<pool>/<img>[@<snap>]:[<part>]:[<fs>]:[<opts>]
rbd_map_parse()
{
    local param="$1" tmp="" old_ifs=$IFS i=1
    if [ -n "${param}" ]; then
        IFS=":"
        for arg in ${param} ; do
            case ${i} in
                1)  tmp=${arg} ;;
                2)  RBD_MONS=$(echo ${arg} | tr ";" ":") ;;
                3)  RBD_ID=${arg%%/*}; RBD_KEY=${arg##*/}
                    if [ "$RBD_KEY" = "secret" ]; then
                        RBD_KEY="your_key"
                    fi ;;
                4)  tmp=${arg%%@*}; RBD_POOL=${tmp%%/*}; RBD_IMG=${tmp##*/}
                    if [ ${arg#*@*} != ${arg} ] ; then
                        RBD_SNAP=${arg##*@}
                    else
                        RBD_SNAP=""
                    fi ;;
                5)  RBD_PART=${arg} ;;
                6)  RBD_FS=${arg}; modprobe $RBD_FS ;;
                7)  RBD_OPTS=${arg} ;;
            esac
            i=$((${i} + 1))
        done
        IFS=${old_ifs}
    fi
}

rbd_map $RBD_ROOT_PATH

exit 0
