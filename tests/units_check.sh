#!/bin/sh
#
# tests/units_check.sh - check_units against enabled units of its own
#
# The enabled units are links in *.wants directories under
# Tiger_Sysctl_Root; systemctl is a script (Tiger_Systemctl_Cmd) that
# answers "cat" with prepared text, laid out as systemctl cat lays it out.
# Units whose permissions are tested name files under the test's own
# directory; the ones that test where a unit comes from name the usual
# /etc and /usr/lib paths, which need not exist for that. Files belong to
# whoever runs the test, so ownership is asserted relative to that.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
cp "$W/tigerrc" "$W/tigerrc.base"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
me=`id -un` uid=`id -u`

# the tree came with the checkout's mode, and (as root) its owner; the
# units' directories must be the runner's alone
chmod 755 "$W"
[ "$uid" = 0 ] && chown -R 0:0 "$W"
r="$W/root"; C="$W/cat"; F="$W/fs"
mkdir -p "$r/etc/systemd/system/multi-user.target.wants" "$r/etc/systemd/system/timers.target.wants" \
  "$r/etc/systemd/system/sockets.target.wants" "$r/usr/lib/systemd/system" "$C" "$F/units" "$F/bin" "$F/open"
for u in good.service bad.service mine.service local.service vendor.service replaced.service
do : > "$r/etc/systemd/system/multi-user.target.wants/$u"; done
: > "$r/etc/systemd/system/timers.target.wants/nightly.timer"
: > "$r/etc/systemd/system/sockets.target.wants/echo.socket"
: > "$r/etc/systemd/system/sockets.target.wants/conn.socket"
: > "$r/usr/lib/systemd/system/replaced.service"
printf '#!/bin/sh\n' > "$F/bin/good"; printf '#!/bin/sh\n' > "$F/open/bad"; chmod 755 "$F/bin/good" "$F/open/bad"
chmod 755 "$F" "$F/bin" "$F/units"; chmod 757 "$F/open"
printf '[Service]\nExecStart=%s\n' "$F/bin/good" > "$F/units/good.service"; chmod 644 "$F/units/good.service"
mkdir -p "$F/units/grp"; chmod 775 "$F/units/grp"
printf '[Service]\nExecStart=%s\n' "$F/bin/good" > "$F/units/grp/mine.service"; chmod 644 "$F/units/grp/mine.service"

# what "systemctl cat NAME" prints
unit() { cat > "$C/$1"; }
unit good.service <<EOF
# $F/units/good.service
[Service]
User=$me
ExecStartPre=-$F/bin/good --check
ExecStart=$F/bin/good
EOF
unit bad.service <<EOF
# $F/units/good.service
[Service]
User=$me
ExecStart=+$F/open/bad
EOF
unit mine.service <<EOF
# $F/units/grp/mine.service
[Service]
ExecStart=$F/bin/good
EOF
unit local.service <<'EOF'
# /etc/systemd/system/local.service
[Service]
# /etc/systemd/system/local.service.d/ is where a drop-in would go
ExecStart=/bin/true
EOF
unit vendor.service <<'EOF'
# /usr/lib/systemd/system/vendor.service
[Service]
ExecStart=/bin/true

# /etc/systemd/system/vendor.service.d/override.conf
[Service]
Nice=5
EOF
unit replaced.service <<'EOF'
# /etc/systemd/system/replaced.service
[Service]
ExecStart=/bin/true
EOF
unit nightly.timer <<'EOF'
# /etc/systemd/system/nightly.timer
[Timer]
OnCalendar=daily
Unit=backup-job.service
EOF
unit backup-job.service <<'EOF'
# /etc/systemd/system/backup-job.service
[Service]
ExecStart=/bin/true
EOF
unit echo.socket <<'EOF'
# /usr/lib/systemd/system/echo.socket
[Socket]
ListenStream=7
EOF
unit echo.service <<'EOF'
# /run/systemd/system/echo.service
[Service]
ExecStart=/bin/true
EOF
unit conn.socket <<'EOF'
# /usr/lib/systemd/system/conn.socket
[Socket]
ListenStream=8
Accept=yes
EOF
unit conn.service <<'EOF'
# /etc/systemd/system/conn.service
[Service]
ExecStart=/bin/true
EOF
printf '#!/bin/sh\n[ "$1" = cat ] && [ "$2" = --no-pager ] && [ -f "%s/$3" ] && exec cat "%s/$3"\nexit 1\n' "$C" "$C" > "$W/sc"

cp "$W/tigerrc.base" "$W/tigerrc"
{ echo "Tiger_Sysctl_Root='$r'"; echo "Tiger_Systemctl_Cmd='sh $W/sc'"; echo "Tiger_Show_INFO_Msgs=Y"; } >> "$W/tigerrc"
( cd "$W" && TIGERHOMEDIR=$W sh ./systems/Linux/2/check_units ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$W/out"
has()   { grep -F -q -- "$1" "$W/out"; }
count() { grep -F -c -- "$1" "$W/out"; }

has "--INFO-- [sysd007i] Some enabled systemd services are defined in /etc or /run (by hand, or generated at boot) rather than shipped by a package. backup-job.service, echo.service, local.service." &&
  ok "local units listed: a timer's Unit=, a socket's own service; not one started per connection (Accept=yes)" || { bad "local"; cat "$W/out"; }
has "[sysd008i]" && has "replaced.service (replaces /usr/lib/systemd/system/replaced.service)" && has "vendor.service (drop-in /etc/systemd/system/vendor.service.d/override.conf)" &&
  ok "a vendor unit replaced in /etc, and one with a drop-in there" || { bad "changed"; cat "$W/out"; }
[ "`count 'local.service.d'`" = 0 ] && ok "a comment starting \"# /etc/...\" is not taken for a file" || { bad "comment"; cat "$W/out"; }
has "--FAIL-- [sysd005f] The systemd unit bad.service runs \`$F/open/bad' which contains \`$F/open' which is world writable." &&
  ok "a program in a world-writable directory: sysd005f (pathmsg, with its letter)" || { bad "world-writable dir"; cat "$W/out"; }
[ "`count \"bad.service runs \\\`$F/open/bad' which contains \\\`$F/open' which is not owned\"`" = 0 ] &&
  ok "User= is the owner expected: the program is $me's and so is fine" || { bad "user"; cat "$W/out"; }
if [ "$uid" != 0 ]; then
  has "[sysd006f] The systemd unit mine.service is made of \`$F/units/grp/mine.service', through \`$W', which is owned by $me" &&
    ok "a unit file not root's: sysd006f (here the test's own directory, $me's)" || { bad "unit file"; cat "$W/out"; }
  has "[sysd004w] The systemd unit mine.service runs \`$F/bin/good' which contains" && has "which is not owned by root (owned by $me)." &&
    ok "no User=: the program must be root's; $me's is sysd004w" || { bad "owner root"; cat "$W/out"; }
else
  has "[sysd006f] The systemd unit mine.service is made of \`$F/units/grp/mine.service', through \`$F/units/grp', which is writable by group" &&
    ok "a unit file in a group-writable directory: sysd006f" || { bad "unit file (root)"; cat "$W/out"; }
  [ "`count 'sysd004'`" = 0 ] && ok "run as root: root's programs need no sysd004" || { bad "owner (root)"; cat "$W/out"; }
fi
[ "`count \"which contains \\\`/tmp'\"`" = 0 ] && ok "/tmp, sticky, is not reported as a writable directory above" || { bad "sticky /tmp"; cat "$W/out"; }
[ "`count 'good.service runs'`" = 0 ] && ok "a unit whose program and directories are in order: nothing" || { bad "good"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
