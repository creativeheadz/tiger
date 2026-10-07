#!/bin/sh
#
# tests/sudo_check.sh - check_sudo against rules and files of its own
#
# The rules are what cvtsudoers -e -f sudoers prints (Hera's own, captured
# 7 October 2026, then one rule per case), through Tiger_Cvtsudoers_Cmd;
# the files are an /etc/sudoers and sudoers.d under Tiger_Sysctl_Root.
# They belong to whoever runs the test, so the owner is expected to be
# reported unless that is root.
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

stub() { { echo '#!/bin/sh'; echo "cat <<'EOT'"; cat; echo 'EOT'; } > "$W/$1"; }
stub hera <<'EOF'
Defaults env_reset
Defaults mail_badpass
Defaults\
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin
Defaults use_pty
Defaults pwfeedback
root ALL = (ALL : ALL) ALL
%admin ALL = (ALL) ALL
%sudo ALL = (ALL : ALL) ALL
andrei ALL = (ALL) NOPASSWD: ALL
ALL ALL = NOPASSWD: /usr/bin/mintdrivers-remove-live-media
ALL ALL = NOPASSWD: /usr/bin/mint-refresh-cache
EOF
stub more <<'EOF'
Defaults:deploy !authenticate
%sudo ALL = (ALL : ALL) ALL
backup ALL = (root) NOPASSWD: /usr/bin/rsync, PASSWD: ALL
ops ALL = (root) /usr/bin/systemctl restart *, !/usr/bin/systemctl restart sshd
web ALL = (www-data) NOPASSWD: /usr/bin/php /srv/app/*.php, \
    /usr/bin/kill
%wheel ALL = (ALL) NOPASSWD: ALL
EOF
printf '#!/bin/sh\necho "cvtsudoers: unable to open /etc/sudoers: Permission denied" >&2\nexit 1\n' > "$W/denied"

r="$W/root"; mkdir -p "$r/etc/sudoers.d"
: > "$r/etc/sudoers"; chmod 0440 "$r/etc/sudoers"; chmod 0755 "$r/etc/sudoers.d"
: > "$r/etc/sudoers.d/ops"; chmod 0440 "$r/etc/sudoers.d/ops"
uid=`id -u`
go() {
  cp "$W/tigerrc.base" "$W/tigerrc"
  { echo "Tiger_Sysctl_Root='$r'"; echo "Tiger_Cvtsudoers_Cmd='sh $W/$1'"; echo "Tiger_Show_INFO_Msgs=Y"; } >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh ./systems/Linux/2/check_sudo ) 2>&1 |
    awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
    tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$W/out"
}
has()   { grep -F -q -- "$1" "$W/out"; }
count() { grep -c -- "$1" "$W/out"; }

go hera
has "--WARN-- [sudo001w] andrei may run any command as root with sudo, without a password" && [ "`count sudo001w`" = 1 ] &&
  ok "Hera: NOPASSWD: ALL for andrei, and nobody else" || { bad "hera nopasswd"; cat "$W/out"; }
has "--INFO-- [sudo002i] Some commands may be run with sudo without a password. ALL: /usr/bin/mint-refresh-cache; ALL: /usr/bin/mintdrivers-remove-live-media." &&
  ok "Hera: Mint's NOPASSWD helpers listed in one INFO" || { bad "hera helpers"; cat "$W/out"; }
[ "`count 'sudo00[34]'`" = 0 ] && ok "Hera: no !authenticate, no wildcard" || { bad "hera extra"; cat "$W/out"; }

go more
has '--WARN-- [sudo003w] sudo asks nobody for a password: "Defaults:deploy !authenticate".' && ok "Defaults !authenticate: sudo003w" || { bad "authenticate"; cat "$W/out"; }
has '[sudo001w] %wheel may run any command as root' && [ "`count 'sudo001w] backup'`" = 0 ] &&
  ok "PASSWD: after NOPASSWD: in one rule puts the password back for ALL" || { bad "passwd tag"; cat "$W/out"; }
has '--WARN-- [sudo004w] ops may run "/usr/bin/systemctl restart *" with sudo' && has 'web may run "/usr/bin/php /srv/app/*.php"' &&
  [ "`count sudo004w`" = 2 ] && ok "wildcards: one sudo004w per command, the negated one left out" || { bad "wildcards"; cat "$W/out"; }
has 'backup: /usr/bin/rsync' && has 'web: /usr/bin/kill' &&
  ok "a continued line: the NOPASSWD tag carries to the next command" || { bad "continuation"; cat "$W/out"; }

if [ "$uid" != 0 ]; then
  has "[sudo005w] \`/etc/sudoers' is owned by uid $uid" && ok "a sudoers file not root's: sudo005w" || { bad "owner"; cat "$W/out"; }
else
  [ "`count sudo005w`" = 0 ] && ok "root's files, mode 0440: no sudo005w" || { bad "owner (root)"; cat "$W/out"; }
fi
chmod 0664 "$r/etc/sudoers.d/ops"
go hera
has "[sudo005w] \`/etc/sudoers.d/ops' is writable by others (-rw-rw-r--" && ok "a group-writable drop-in: sudo005w" || { bad "writable"; cat "$W/out"; }
chmod 0440 "$r/etc/sudoers.d/ops"

go denied
has '--ERROR-- [sudo006e] sudo'"'"'s rules cannot be read' && has 'Permission denied' && ok "cvtsudoers refused: sudo006e" || { bad "denied"; cat "$W/out"; }
rm -f "$r/etc/sudoers"; go hera
[ "`count .`" = 0 ] && ok "no /etc/sudoers (no sudo): nothing said" || { bad "no sudo"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
