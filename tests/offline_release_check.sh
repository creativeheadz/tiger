#!/bin/sh
#
# tests/offline_release_check.sh - the OS release check on offline roots
#
# Five roots, each an old system of a different family: Debian 8.11, a
# Debian trixie, Ubuntu 14.04, RHEL 7.2, and Red Hat Linux 7.1. Each
# must be reported out of date (or unreleased) from its own release
# files. The Ubuntu run shadows lsb_release with a failing stub, so
# its finding proves the root's os-release was read and this host was
# never asked. The Red Hat root also carries a debian_version: the
# dispatcher only runs this check for Debian-family roots, and the leg
# itself reads no other file. The RHEL leg is unreachable through the
# dispatcher (its distributor never coincides with that gate), so it
# is run directly with TIGRIS_ROOT set, the way the unit would see it.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
uid=`id -u`
[ "$uid" = 0 ] && chown -R 0:0 "$W"

D=$W/debnum;  mkdir -p "$D/etc"; printf '8.11\n' > "$D/etc/debian_version"
C=$W/debname; mkdir -p "$C/etc"; printf 'trixie\n' > "$C/etc/debian_version"
U=$W/ubuntu;  mkdir -p "$U/etc"; printf '24.04\n' > "$U/etc/debian_version"
printf 'ID=ubuntu\nVERSION_ID="14.04"\n' > "$U/etc/os-release"
H=$W/rhel;    mkdir -p "$H/etc"
printf 'DISTRIB_ID=RedHatEnterpriseServer\nDISTRIB_RELEASE=7.2\n' > "$H/etc/lsb-release"
V=$W/redhat;  mkdir -p "$V/etc"; printf 'Red Hat Linux release 7.1 (Seawolf)\n' > "$V/etc/redhat-release"
printf '7.1\n' > "$V/etc/debian_version"

# A failing lsb_release early in PATH: any finding under it proves the
# root's files were read, since asking the host yields nothing.
mkdir -p "$W/fakebin"
printf '#!/bin/sh\nexit 3\n' > "$W/fakebin/lsb_release"
chmod 755 "$W/fakebin/lsb_release"

{
  sed -n 's/^\(Tiger_Check_[A-Z_]*\)=.*/\1=N/p' "$W/tigerrc"
  echo 'Tiger_Deb_CheckMD5Sums=N'; echo 'Tiger_Deb_NoPackFiles=N'; echo 'Tiger_Deb_StatOverride=N'
  for c in OS SYSTEM; do echo "Tiger_Check_$c=Y"; done
} > "$W/profiles/release"
chmod 644 "$W/profiles/release"

run() {
  sleep 2
  if [ "$3" = stub ]; then
    ( cd "$W" && PATH="$W/fakebin:$PATH" sh ./tigris -q --profile release --root "$2" ) > "$W/out$1" 2>&1
  else
    ( cd "$W" && sh ./tigris -q --profile release --root "$2" ) > "$W/out$1" 2>&1
  fi
  json=`ls -t "$W"/log/*.jsonl 2>/dev/null | head -1`
  [ -n "$json" ] || { echo "FAIL no report $1:"; cat "$W/out$1"; exit 1; }
  grep '"type":"finding"' "$json" | grep -q "$2" && bad "run $1 names the root's directory on this host" ||
    ok "run $1 names the root's own paths"
  sh "$W/tests/schema_check.sh" "$json" > "$W/schema$1.out" 2>&1 && ok "report $1 validates" ||
    { grep -q SKIP "$W/schema$1.out" && ok "(schema not checked: $(cat "$W/schema$1.out"))" || { bad "schema$1"; cat "$W/schema$1.out"; }; }
}

run 1 "$D"
grep -q '"id":"osv002f".*Out of date Debian GNU/Linux version .8.11' "$json" &&
  ok "Debian 8.11: osv002f" || bad "osv002f debnum"
run 2 "$C"
grep -q '"id":"osv004w".*Unreleased Debian GNU/Linux version .trixie' "$json" &&
  ok "Debian trixie: osv004w" || bad "osv004w"
run 3 "$U" stub
grep -q '"id":"osv002f".*Out of date Ubuntu Linux version .14.04' "$json" &&
  ok "Ubuntu 14.04, lsb_release stubbed out: osv002f" || bad "osv002f ubuntu"
run 4 "$V"
grep -q '"id":"osv001f".*Out of date Red Hat Linux version 7.1' "$json" &&
  ok "Red Hat Linux 7.1: osv001f" || bad "osv001f"

( cd "$W" && TIGRIS_ROOT="$H" TIGERHOMEDIR="$W" sh ./systems/Linux/2/check_release ) > "$W/direct.out" 2>&1
grep -q 'osv002f.*Out of date Red Hat Enterprise Linux version .7.2' "$W/direct.out" &&
  ok "RHEL 7.2 by its lsb-release, run directly: osv002f" || bad "osv002f rhel"

[ $fail -eq 0 ] && echo "PASS" || { echo "--- findings"; grep -h '"type":"finding"' "$W"/log/*.jsonl | cut -c1-220; }
exit $fail
