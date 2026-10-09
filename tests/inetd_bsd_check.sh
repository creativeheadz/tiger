#!/bin/sh
#
# tests/inetd_bsd_check.sh - FreeBSD check_inetd on offline roots
#
# Three legs: inetd enabled with telnet and finger (inet001w
# naming both); enabled with only daytime (silent); and
# disabled with telnet configured (dormant, silent). Runs as a
# user and as root; the fixtures read the same for both.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
umask 022
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
run() {  # run ROOT OUTFILE: check_inetd with ROOT as the audited system
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/FreeBSD/default/check_inetd ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }
empty() { [ ! -s "$1" ]; }
root() {  # root DIR RC INETD: a root with the rc line and inetd.conf
  mkdir -p "$1/etc"
  printf '%s\n' "$2" > "$1/etc/rc.conf"
  printf '%s\n' "$3" > "$1/etc/inetd.conf"
}

B=$W/bad
root "$B" 'inetd_enable="YES"' 'telnet stream tcp nowait root /usr/libexec/telnetd
finger stream tcp nowait nobody /usr/libexec/fingerd
daytime stream tcp nowait root internal'
run "$B" "$W/out"
has '--WARN-- [inet001w]' "$W/out" &&
has 'telnet' "$W/out" &&
has 'finger' "$W/out" &&
  ok "telnet and finger: both named" || { bad "bad"; cat "$W/out"; }

T=$W/tight
root "$T" 'inetd_enable="YES"' 'daytime stream tcp nowait root internal'
run "$T" "$W/out"
empty "$W/out" &&
  ok "daytime alone: silent" || { bad "tight noisy"; cat "$W/out"; }

D=$W/dormant
root "$D" 'inetd_enable="NO"' 'telnet stream tcp nowait root /usr/libexec/telnetd'
run "$D" "$W/out"
empty "$W/out" &&
  ok "disabled with telnet: silent" || { bad "dormant noisy"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
