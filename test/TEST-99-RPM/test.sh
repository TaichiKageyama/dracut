#!/bin/bash

TEST_DESCRIPTION="rpm integrity after dracut and kernel install"

test_check() {
    command -v rpm &>/dev/null && ( command -v yum || command -v dnf ) &>/dev/null
}

test_run() {
    set -x
    set -e
    export rootdir=$TESTDIR/root

    mkdir -p $rootdir

    mkdir -p "$rootdir/proc"
    mkdir -p "$rootdir/sys"
    mkdir -p "$rootdir/dev"

trap 'ret=$?; [[ -d $rootdir ]] && { umount "$rootdir/proc"; umount "$rootdir/sys"; umount "$rootdir/dev"; rm -rf -- "$rootdir"; } || :; exit $ret;' EXIT
trap '[[ -d $rootdir ]] && { umount "$rootdir/proc"; umount "$rootdir/sys"; umount "$rootdir/dev"; rm -rf -- "$rootdir"; } || :; exit 1;' SIGINT

    mount --bind /proc "$rootdir/proc"
    mount --bind /sys "$rootdir/sys"
    mount -t devtmpfs devtmpfs "$rootdir/dev"

    dnf_or_yum=yum
    command -v dnf >/dev/null && dnf_or_yum="dnf --allowerasing"
    $dnf_or_yum --releasever=7 --nogpgcheck --installroot "$rootdir"/ install -y \
	$dnf_or_yum \
	passwd \
	rootfiles \
	systemd \
	kernel \
	device-mapper-multipath \
	lvm2 \
	mdadm \
        bash \
        iscsi-initiator-utils \
        "$TESTDIR"/dracut-[0-9]*.$(arch).rpm \
        "$TESTDIR"/dracut-network-[0-9]*.$(arch).rpm

    cat >"$rootdir"/test.sh <<EOF
#!/bin/bash
set -x
export LC_MESSAGES=C
rpm -Va |& grep -F -v '85-display-manager.preset' &> /test.output 
find / -xdev -type f -not -path '/var/*' \
  -not -path '/usr/lib/modules/*/modules.*' \
  -not -path '/etc/*-' \
  -not -path '/etc/.pwd.lock' \
  -not -path '/run/mount/utab' \
  -not -path '/test.sh' \
  -not -path '/test.output' \
  -not -path '/etc/nsswitch.conf.bak' \
  -not -path '/etc/iscsi/initiatorname.iscsi' \
  -not -path '/boot/*0-rescue*' \
  -not -path '/usr/share/mime/*' \
  -not -path '/etc/crypto-policies/*' \
  -not -path '/dev/null' \
  -not -path "/boot/loader/entries/\$(cat /etc/machine-id)-*" \
  -not -path "/boot/\$(cat /etc/machine-id)/*" \
  -not -path '/etc/openldap/certs/*' \
  -print0 | xargs -0 rpm -qf | \
  grep -F 'not owned' &>> /test.output
exit 0
EOF

    chmod 0755 "$rootdir/test.sh"

    chroot "$rootdir" /test.sh || :

    if [[ -s "$rootdir"/test.output ]]; then
	failed=1
	echo TEST Failed >&2
	cat "$rootdir"/test.output >&2
    fi

    umount "$rootdir/proc"
    umount "$rootdir/sys"
    umount "$rootdir/dev"

    [[ $failed ]] && return 1
    return 0

}

test_setup() {
    make -C "$basedir" DESTDIR="$TESTDIR/" rpm
    return 0
}

test_cleanup() {
    rm -fr -- "$TESTDIR"/*.rpm
    return 0
}

. $testdir/test-functions
