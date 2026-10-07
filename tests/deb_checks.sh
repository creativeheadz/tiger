#!/bin/sh
#
# tests/deb_checks.sh - the Debian package checks against planted problems
#
# Run as root in a throwaway Debian or Ubuntu container. It modifies one
# packaged binary, deletes another, adds a stray file to /usr/sbin and an
# override (dpkg-statoverride, without --update) that a binary does not
# match, then runs deb_checkmd5sums, deb_nopackfiles and deb_statoverride
# from a root-owned copy of this tree and checks that exactly those four
# are reported.
#
# Exit 0 when every assertion holds, 1 otherwise, 2 when it cannot run.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

[ "`id -u`" = 0 ] || { echo "SKIP: must run as root, in a throwaway container"; exit 2; }
[ -d /var/lib/dpkg/info ] || { echo "SKIP: not a dpkg system"; exit 2; }
[ -f /.dockerenv ] || [ -n "$CI" ] || [ -n "$TIGER_TEST_I_MEAN_IT" ] || {
  echo "SKIP: this test damages the system it runs on; set TIGER_TEST_I_MEAN_IT=1 in a container"; exit 2; }

W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
chown -R 0:0 "$W"
mkdir -p "$W/run" "$W/log"

# Plant the problems
echo tampered >> /usr/bin/xargs
rm -f /usr/bin/sdiff
echo x > /usr/sbin/zz-tiger-stray
dpkg-statoverride --add root root 0700 /usr/bin/cmp

cd "$W"
for check in deb_checkmd5sums deb_nopackfiles deb_statoverride
do
  TIGERHOMEDIR=$W sh systems/Linux/2/$check
done 2>&1 |
# Join the lines Tiger wraps, so a path is on the same line as its code
awk '/^--/ { if (l != "") print l; l = $0; next } { sub(/^ +/, " "); l = l $0 } END { if (l != "") print l }' > "$W/report"

fail=0
expect()
{
  if grep -q "$1" "$W/report"; then
    echo "ok   $2"
  else
    echo "FAIL $2"
    fail=1
  fi
}
expect "lin005f.*/usr/bin/xargs"       "modified binary reported (lin005f)"
expect "lin006f.*/usr/bin/sdiff"       "deleted binary reported (lin006f)"
expect "lin001w.*/usr/sbin/zz-tiger-stray" "stray file reported (lin001w)"
expect "lin039w.*/usr/bin/cmp.*sets root:root 700; the file is root:root 755" "file not matching its override reported (lin039w)"
if [ "`grep -c lin039w "$W/report"`" = 1 ]; then
  echo "ok   no other override mismatches"
else
  echo "FAIL other override mismatches:"; grep lin039w "$W/report"; fail=1
fi

# Docker drops /usr/sbin/policy-rc.d into images; nothing else may be unowned
unowned=`grep -c 'lin001w' "$W/report"`
others=`grep 'lin001w' "$W/report" | grep -vc 'zz-tiger-stray\|policy-rc.d'`
if [ "$others" -eq 0 ]; then
  echo "ok   no other unowned files ($unowned lin001w in all)"
else
  echo "FAIL $others unexpected unowned files:"
  grep 'lin001w' "$W/report" | grep -v 'zz-tiger-stray\|policy-rc.d' | head -5
  fail=1
fi

[ $fail -eq 0 ] && echo "PASS" || { echo "--- report"; cat "$W/report"; }
exit $fail
