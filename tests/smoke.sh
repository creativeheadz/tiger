#!/bin/sh
#
# tests/smoke.sh - a full Tiger run from a root-owned copy of this tree
#
# Checks that tiger exits 0, writes a report, runs every check it was asked
# to (no misc024e/misc025e/misc005e), and prints how long it took and what
# it found. Run as root.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

[ "`id -u`" = 0 ] || { echo "SKIP: must run as root"; exit 2; }

W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git -cf - . ) | ( cd "$W" && tar -xf - )
chown -R 0:0 "$W"
cd "$W"
sh util/genmsgidx doc/*.txt >/dev/null 2>&1

start=`date +%s`
sh ./tiger > "$W/stdout" 2> "$W/stderr"
status=$?
end=`date +%s`

fail=0
report=`ls "$W"/log/security.report.* 2>/dev/null | head -1`
[ "$status" -eq 0 ] && echo "ok   tiger exited 0" || { echo "FAIL tiger exited $status"; fail=1; }
[ -n "$report" ] && echo "ok   report written: ${report#$W/}" || { echo "FAIL no report in log/"; fail=1; }

if [ -n "$report" ]; then
  skipped=`grep -c 'misc024e\|misc025e\|misc005e' "$report"`
  [ "$skipped" -eq 0 ] && echo "ok   no check was skipped" || {
    echo "FAIL $skipped checks were skipped:"; grep 'misc024e\|misc025e\|misc005e' "$report" | head; fail=1; }
  echo "---  `expr $end - $start`s, `wc -l < "$report"` report lines"
  grep -oE -- '--(FAIL|WARN|ALERT|INFO|ERROR)--' "$report" | sort | uniq -c | sed 's/^/     /'
  echo "---  by code"
  grep -oE '\[[a-z]+[0-9]{3}[a-z]\]' "$report" | sort | uniq -c | sort -rn | head -15 | sed 's/^/     /'
fi
if [ -s "$W/stderr" ]; then
  echo "---  stderr"
  sort "$W/stderr" | uniq -c | sort -rn | head -10 | sed 's/^/     /'
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
