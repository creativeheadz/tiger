#!/bin/sh
#
# tests/pkg_checks.sh - pkg_integrity against planted problems, on RPM, apk
#                       and pacman systems
#
# Run as root in a throwaway Fedora (or other RPM), Alpine or Arch
# container, as tests/deb_checks.sh does for Debian. It modifies one
# packaged binary, deletes another, changes the mode of a third and adds a
# stray file to /usr/bin, runs pkg_integrity from a root-owned copy of this
# tree and checks that exactly those four are reported, with the same
# message ids the Debian checks use.
#
# Exit 0 when every assertion holds, 1 otherwise, 2 when it cannot run.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

[ "`id -u`" = 0 ] || { echo "SKIP: must run as root, in a throwaway container"; exit 2; }
[ -f /.dockerenv ] || [ -n "$CI" ] || [ -n "$TIGER_TEST_I_MEAN_IT" ] || {
  echo "SKIP: this test damages the system it runs on; set TIGER_TEST_I_MEAN_IT=1 in a container"; exit 2; }

# Tiger cannot run without these; a stripped image may not have them
for c in awk sed sort find grep tar; do
  command -v $c >/dev/null 2>&1 || { echo "SKIP: $c is needed and this image has none (install it first)"; exit 2; }
done

if   command -v rpm    >/dev/null 2>&1; then mgr=rpm
elif command -v apk    >/dev/null 2>&1; then mgr=apk
elif command -v pacman >/dev/null 2>&1; then mgr=pacman
else echo "SKIP: no rpm, apk or pacman here"; exit 2; fi

# a packaged binary to change, one to delete, one to chmod; Tiger itself
# must not depend on the one deleted
case "$mgr" in
  rpm)    MOD=/usr/bin/xargs; DEL=/usr/bin/nl; PRM=/usr/bin/cut ;;
  apk)    apk add -q --no-cache findutils diffutils >/dev/null 2>&1
          MOD=/usr/bin/xargs; DEL=/usr/bin/diff; PRM=/usr/bin/cmp ;;
  pacman) MOD=/usr/bin/pwd; DEL=/usr/bin/nl; PRM=/usr/bin/cat ;;
esac
STRAY=/usr/bin/zz-tiger-stray

W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git -cf - . ) | ( cd "$W" && tar -xf - )
chown -R 0:0 "$W"
mkdir -p "$W/run" "$W/log"

run()
{
  ( cd "$W" && TIGERHOMEDIR=$W sh systems/Linux/2/pkg_integrity 2>&1 ) |
  awk '/^--(FAIL|WARN)/ { if (l != "") print l; l = $0; next } /^--/ { if (l != "") print l; l = ""; next } /^ / { sub(/^ +/, " "); l = l $0; next } END { if (l != "") print l }' | sort -u
}

# A real image has findings of its own (an image strips setuid bits, a
# package declares a directory the image left out). What the test claims
# is what the four changes ADD to that baseline.
run > "$W/baseline"
# pacman's NoExtract and NoUpgrade say which files are meant to be absent or
# different; none of those may show up as findings
if grep -q 'lin006f.*"/usr/share/' "$W/baseline"; then
  echo "FAIL baseline reports /usr/share files the package manager is told not to install:"
  grep 'lin006f.*"/usr/share/' "$W/baseline" | head -3; exit 1
fi

echo tampered >> "$MOD"
rm -f "$DEL"
chmod 777 "$PRM"
echo x > "$STRAY"

run > "$W/after"
comm -13 "$W/baseline" "$W/after" > "$W/report"
echo "(baseline had `wc -l < "$W/baseline"` findings of its own; the changes added `wc -l < "$W/report"`)"

fail=0
expect()
{
  if grep -q "$1" "$W/report"; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi
}
expect "lin005f.*$MOD"      "modified binary reported as lin005f ($mgr)"
expect "lin006f.*$DEL"      "deleted binary reported as lin006f ($mgr)"
expect "lin038w.*$PRM"      "changed mode reported as lin038w ($mgr)"
expect "lin001w.*$STRAY"    "stray file reported as lin001w ($mgr)"

added=`grep -c 'lin00[156]\|lin038w' "$W/report"`
if [ "$added" -eq 4 ]; then
  echo "ok   the four changes added exactly four findings"
else
  echo "FAIL the changes added $added findings, wanted 4:"; cat "$W/report"; fail=1
fi
grep -q 'lin005f.*package .unknown' "$W/report" && { echo "FAIL a package name was not found"; fail=1; }

[ $fail -eq 0 ] && echo "PASS" || { echo "--- report"; cat "$W/report"; }
exit $fail
