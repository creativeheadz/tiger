#!/bin/sh
#
# tests/accounting_bsd_check.sh - FreeBSD check_accounting on roots
#
# Three legs: accounting off (act001w); enabled with the file
# (silent); and enabled without the file (act001w naming it).
# Runs as a user and as root; the fixtures read the same for
# both.
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
run() {  # run ROOT OUTFILE: check_accounting with ROOT as the audited system
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/FreeBSD/default/check_accounting ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }
empty() { [ ! -s "$1" ]; }
rc() {  # rc ROOT LINE: an rc.conf with the accounting line
  mkdir -p "$1/etc"
  printf '%s\n' "$2" > "$1/etc/rc.conf"
}

O=$W/off; rc "$O" 'accounting_enable="NO"'
mkdir -p "$O/var/account"
run "$O" "$W/out"
has '--WARN-- [act001w]' "$W/out" &&
  ok "accounting off: act001w" || { bad "off"; cat "$W/out"; }

T=$W/tight; rc "$T" 'accounting_enable="YES"'
mkdir -p "$T/var/account"
touch "$T/var/account/acct"
run "$T" "$W/out"
empty "$W/out" &&
  ok "enabled with the file: silent" || { bad "tight noisy"; cat "$W/out"; }

M=$W/missing; rc "$M" 'accounting_enable="YES"'
mkdir -p "$M/var/account"
run "$M" "$W/out"
has '--WARN-- [act001w]' "$W/out" &&
has 'missing' "$W/out" &&
  ok "enabled without the file: act001w" || { bad "missing"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
