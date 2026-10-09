#!/bin/sh
#
# tests/audit_macos_check.sh - MacOSX check_audit on offline roots
#
# Three legs: no audit_control (aud001w); flags recording almost
# nothing (aud002w); and flags recording logins and admin actions,
# which is silent. Runs as a user and as root; the fixtures read
# the same for both.
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
run() {  # run ROOT OUTFILE: check_audit with ROOT as the audited system
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/MacOSX/default/check_audit ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }
empty() { [ ! -s "$1" ]; }
control() {  # control ROOT FLAGS: an audit_control with the flags
  mkdir -p "$1/etc/security"
  cat > "$1/etc/security/audit_control" <<EOF
dir:/var/audit
flags:$2
minfree:5
naflags:lo
policy:cnt,argv
filesz:2M
expire-after:10M
EOF
}

N=$W/none; mkdir -p "$N/etc"
run "$N" "$W/out"
has '--WARN-- [aud001w]' "$W/out" &&
  ok "no audit_control: aud001w" || { bad "none"; cat "$W/out"; }

E=$W/empty; mkdir -p "$E/etc"; control "$E" ""
run "$E" "$W/out"
has '--WARN-- [aud002w]' "$W/out" &&
  ok "empty flags: aud002w" || { bad "empty"; cat "$W/out"; }

T=$W/tight; mkdir -p "$T/etc"; control "$T" "lo,ad,fm,fw"
run "$T" "$W/out"
empty "$W/out" &&
  ok "flags recording logins and admin: silent" || { bad "tight noisy"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
