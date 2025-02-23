#!/bin/sh
# Scenario:
#  create exec1 jail
#  execute:
#
#    cbsd jexec jname=exec1

oneTimeSetUp() {
	ver=14
	jname="jexec1"
	cbsd jdestroy jname=${jname} || true
}

setUp() {
	cbsd jcreate jname=${jname} runasap=1 ver=${ver}
	dir=$(mktemp -d)
	cd "${dir}" || exit
}

tearDown() {
	cbsd jremove ${jname}
	rm -rf "${dir}"
}

# simple jexec
testSimpleJexec() {
	test="cbsd jexec jname=${jname} hostname"
	echo "test: ${test}"
	test=$(${test})
	assertEquals "${test}" "${jname}.my.domain"
}

# pwd
testPwd() {
	test="cbsd jexec jname=${jname} dir=/tmp pwd"
	echo "test: ${test}"
	test=$(${test})
	assertEquals "${test}" "/tmp"
}

# HEREDOC
testHereDoc() {
	test=$(
		cbsd jexec jname=${jname} <<EOF
hostname
EOF
	)
	assertEquals "${test}" "${jname}.my.domain"
}

### CBSDfile
testCBSDFile() {
	cat >CBSDfile <<EOF
quiet=0

jail_${jname}()
{
        ip4_addr="DHCP"
        host_hostname="${jname}.my.domain"
        pkg_bootstrap=1
        runasap=1
        ver="${ver}"
}

postcreate_${jname}()
{
        set +o xtrace

        sysrc \
                syslogd_flags="-ss" \
                syslogd_enable="YES" \
                cron_enable="NO" \
                sendmail_enable="NO" \
                sendmail_submit_enable="NO"\
                sendmail_outbound_enable="NO" \
                sendmail_msp_queue_enable="NO" \
        # execute cmd inside jail
        jexec dir=/tmp <<XEOF
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin
pwd > /tmp/jexec.file
hostname
XEOF

}
EOF
	cp -a CBSDfile /tmp/

	cbsd up

	. /etc/rc.conf

	assertTrue "[ -r ${cbsd_workdir}/jails-data/${jname}-data/tmp/jexec.file ]"

	test=$(cat "${cbsd_workdir}"/jails-data/${jname}-data/tmp/jexec.file)

	assertEquals "failed: no /tmp pwd in ${cbsd_workdir}/jails-data/${jname}-data/tmp/jexec.file" "${test}" "/tmp"
}

# TODO1: jexec jname='*'
# TODO2: CBSDfile + API

. shunit2
