#!/bin/bash

[ -z "$root" ] && root=$(getarg root=)

if [ "${root%%:*}" = "rbd" -o "$root" = "dhcp" ]; then
    info "1st call from cmdline hook"
    netroot=$root

    # Shut up init error check
    root=block:/dev/root
    wait_for_dev -n /dev/root
elif [ ! -z $netroot ]; then
        info "2nd call from netroot.sh"
        if [ "${netroot%%:*}" != "rbd" ]; then
                warn "$netroot is invalid"
                exit 1
        fi
else
    warn "$root is invalid"
    exit 1
fi

rootok=1
