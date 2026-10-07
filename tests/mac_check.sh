#!/bin/sh
#
# tests/mac_check.sh - check_mac against /sys trees of its own
#
# Each case is a /sys with the list of active security modules and
# AppArmor's profiles (one per line, "name (mode)", as securityfs shows
# them to root) or SELinux's enforce flag, fed through Tiger_Sysctl_Root.
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

# sys NAME LSM-LIST: a /sys whose security modules are LSM-LIST ("-" for
# a kernel without the list)
sys() {
  s="$W/$1/sys"; mkdir -p "$s/kernel/security" "$s/module"
  [ "$2" != - ] && echo "$2" > "$s/kernel/security/lsm"
  :
}
profiles() {  # profiles NAME, the lines on stdin
  mkdir -p "$W/$1/sys/kernel/security/apparmor"; cat > "$W/$1/sys/kernel/security/apparmor/profiles"
}
go() {
  cp "$W/tigerrc.base" "$W/tigerrc"
  { echo "Tiger_Sysctl_Root='$W/$1'"; echo "Tiger_Show_INFO_Msgs=Y"; } >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh ./systems/Linux/2/check_mac ) 2>&1 |
    awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
    tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$W/out"
}
has()   { grep -F -q -- "$1" "$W/out"; }
count() { grep -c -- "$1" "$W/out"; }

sys aa "lockdown,capability,landlock,yama,apparmor"
printf '%s\n' '/usr/sbin/cupsd (enforce)' 'snap.firefox.firefox (enforce)' 'transmission-gtk (complain)' 'chrome (unconfined)' | profiles aa
go aa
has '--INFO-- [mac003i] AppArmor is enforcing 2 profiles (1 in complain mode, 1 unconfined). In complain mode, which logs and does not deny: transmission-gtk.' &&
  [ "`count .`" = 1 ] && ok "AppArmor enforcing, profiles counted by mode, complain ones named" || { bad "apparmor"; cat "$W/out"; }
sys aacomplain "capability,apparmor"
printf '%s\n' 'a (complain)' 'b (complain)' | profiles aacomplain
go aacomplain
has '--WARN-- [mac001w] No mandatory access control is enforcing' && has 'no profile is in enforce mode (2 in complain mode, 0 unconfined)' &&
  ok "AppArmor with every profile in complain mode: mac001w" || { bad "apparmor complain"; cat "$W/out"; }
sys aanoread "capability,apparmor"
go aanoread
has '--ERROR-- [mac004e] AppArmor is active, but its profiles cannot be read' && ok "profiles unreadable: mac004e" || { bad "unreadable"; cat "$W/out"; }
sys aaold -
mkdir -p "$W/aaold/sys/module/apparmor/parameters"; echo Y > "$W/aaold/sys/module/apparmor/parameters/enabled"
echo '/usr/sbin/ntpd (enforce)' | profiles aaold
go aaold
has 'AppArmor is enforcing 1 profile (0 in complain mode' && ok "a kernel without the LSM list: AppArmor found by its module" || { bad "old kernel"; cat "$W/out"; }
sys se "capability,selinux"
mkdir -p "$W/se/sys/fs/selinux"; echo 1 > "$W/se/sys/fs/selinux/enforce"
go se
has '--INFO-- [mac003i] SELinux is enforcing.' && ok "SELinux enforcing: mac003i" || { bad "selinux"; cat "$W/out"; }
echo 0 > "$W/se/sys/fs/selinux/enforce"
go se
has '--WARN-- [mac002w] SELinux is in permissive mode' && ok "SELinux permissive: mac002w" || { bad "permissive"; cat "$W/out"; }
sys none "capability,yama,landlock"
go none
has '[mac001w]' && has 'Neither AppArmor nor SELinux is active (security modules: capability,yama,landlock).' &&
  ok "neither: mac001w, naming the modules that are active" || { bad "none"; cat "$W/out"; }
mkdir -p "$W/empty"
go empty
[ "`count .`" = 0 ] && ok "no /sys/kernel: nothing said" || { bad "empty"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
