#!/bin/sh
#
# tests/crontabs_macos_check.sh - MacOSX check_crontabs on offline roots
#
# Two legs: a loose root (a world-writable user tab, a relative
# command in the system crontab, a group-writable periodic job)
# and a tight root (locked tabs, full pathnames, locked jobs).
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
run() {  # run ROOT OUTFILE: check_crontabs with ROOT as the audited system
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/MacOSX/default/check_crontabs ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }
empty() { [ ! -s "$1" ]; }

B=$W/bad
mkdir -p "$B/etc" "$B/var/at/tabs" "$B/etc/periodic/daily"
cat > "$B/etc/crontab" <<'EOF'
# system crontab
17 * * * * root /usr/bin/true
18 * * * * root backup-now
EOF
chmod 644 "$B/etc/crontab"
printf '0 9 * * * /usr/local/bin/good\n' > "$B/var/at/tabs/helen"
chmod 666 "$B/var/at/tabs/helen"
printf '#!/bin/sh\n/usr/bin/true\n' > "$B/etc/periodic/daily/100.clean"
chgrp "`awk -F: '$1 != "root" { print $1; exit }' /etc/group`" "$B/etc/periodic/daily/100.clean" 2>/dev/null || true
chmod 664 "$B/etc/periodic/daily/100.clean"
run "$B" "$W/out"
has '--FAIL-- [cron008f]' "$W/out" &&
has 'helen' "$W/out" &&
has '--WARN-- [cron001w]' "$W/out" &&
has 'backup-now' "$W/out" &&
has '--WARN-- [cron008w]' "$W/out" &&
  ok "writable tab, relative command, writable job: all three" || { bad "bad"; cat "$W/out"; }

T=$W/tight
mkdir -p "$T/etc" "$T/var/at/tabs" "$T/etc/periodic/daily"
printf '17 * * * * root /usr/bin/true\n' > "$T/etc/crontab"
chmod 644 "$T/etc/crontab"
printf '0 9 * * * /usr/local/bin/good\n' > "$T/var/at/tabs/helen"
chmod 600 "$T/var/at/tabs/helen"
printf '#!/bin/sh\n/usr/bin/true\n' > "$T/etc/periodic/daily/100.clean"
chmod 755 "$T/etc/periodic/daily/100.clean"
run "$T" "$W/out"
if [ "`id -u`" -eq 0 ]; then
  empty "$W/out" &&
    ok "locked tabs, full pathnames: silent" || { bad "tight noisy"; cat "$W/out"; }
else
  # as a user the fixtures stay user-owned: the ownership judgment
  # reports them, which proves it works
  has '--WARN-- [cron009w]' "$W/out" &&
    ok "user-owned tabs: ownership reported" || { bad "tight blind"; cat "$W/out"; }
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
