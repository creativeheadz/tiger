#!/bin/sh
#
# tests/sysctl_check.sh - check_sysctl against a tree of known values
#
# Builds a fake /proc/sys with every setting at its worst value and checks
# that each message code appears, then one with every setting right and
# checks that nothing is reported. Needs no root and touches nothing
# outside a temporary directory.
#
# Exit 0 when every assertion holds, 1 otherwise.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"

# key value  (bad)        key value  (good)
settings='
kernel/kptr_restrict                        0 2
kernel/dmesg_restrict                       0 1
kernel/yama/ptrace_scope                    0 1
kernel/randomize_va_space                   0 2
kernel/sysrq                                1 176
kernel/unprivileged_bpf_disabled            0 2
kernel/perf_event_paranoid                  1 3
fs/suid_dumpable                            1 2
fs/protected_hardlinks                      0 1
fs/protected_symlinks                       0 1
fs/protected_fifos                          0 2
fs/protected_regular                        0 2
net/ipv4/conf/all/send_redirects            1 0
net/ipv4/conf/default/send_redirects        1 0
net/ipv4/icmp_ignore_bogus_error_responses  0 1
net/ipv6/conf/all/accept_redirects          1 0
net/ipv6/conf/default/accept_redirects      1 0
net/ipv6/conf/all/accept_source_route       1 0
net/ipv6/conf/default/accept_source_route   1 0
'
expected="lin020w lin021w lin022w lin023f lin024w lin025w lin026w lin027w lin028f lin029f lin030w lin031w lin032w lin033w lin034w lin035f lin036w"

build()
{
  # $1 = tree, $2 = column (2 bad, 3 good)
  echo "$settings" | while read key bad good
  do
    [ -z "$key" ] && continue
    mkdir -p "$1/proc/sys/`dirname $key`"
    if [ "$2" = 2 ]; then echo "$bad"; else echo "$good"; fi > "$1/proc/sys/$key"
  done
  # the kernel's CPU vulnerability verdicts
  mkdir -p "$1/sys/devices/system/cpu/vulnerabilities"
  echo "Not affected" > "$1/sys/devices/system/cpu/vulnerabilities/meltdown"
  echo "Mitigation: Retpolines; IBPB: conditional" > "$1/sys/devices/system/cpu/vulnerabilities/spectre_v2"
  if [ "$2" = 2 ]; then echo "Vulnerable: No microcode"; else echo "Mitigation: Clear CPU buffers"; fi > "$1/sys/devices/system/cpu/vulnerabilities/mds"
}

run()
{
  # $1 = tree. The setting goes in the copy's tigerrc, which config exports
  echo "Tiger_Sysctl_Root='$1'" >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh systems/Linux/2/check_sysctl 2>&1 )
  sed -i '$d' "$W/tigerrc"
}

fail=0
build "$W/bad" 2
run "$W/bad" > "$W/bad.out"
for code in $expected
do
  if grep -q "\[$code\]" "$W/bad.out"; then
    echo "ok   $code reported for the bad value"
  else
    echo "FAIL $code missing"; fail=1
  fi
done

build "$W/good" 3
run "$W/good" > "$W/good.out"
if grep -q -- '--\(WARN\|FAIL\|ALERT\)--' "$W/good.out"; then
  echo "FAIL good tree still reported:"; grep -- '--' "$W/good.out" | head; fail=1
else
  echo "ok   nothing reported for the good tree"
fi

# A kernel without a knob is not a finding
rm "$W/good/proc/sys/kernel/unprivileged_bpf_disabled"
run "$W/good" > "$W/missing.out"
if grep -q -- '--\(WARN\|FAIL\|ALERT|ERROR\)--' "$W/missing.out"; then
  echo "FAIL a missing setting was reported"; fail=1
else
  echo "ok   a missing setting is skipped"
fi

[ $fail -eq 0 ] && echo "PASS" || { echo "--- bad.out"; cat "$W/bad.out"; }
exit $fail
