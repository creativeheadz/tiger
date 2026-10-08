#!/bin/sh
#
# tests/progress_check.sh - timestamps with seconds, and the spinner
#
# Runs the real tigris from a copy of the tree with every check off
# except check_system, slowed to a second so an animated line has time
# to move. Piped (as in cron and CI), the progress lines carry seconds
# and no carriage returns; on a terminal they spin in place and finish
# as the same lines; -q prints none of them.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/log" "$W/run"
# as root, the tree must be root's for Tigris to run its scripts
[ "`id -u`" = 0 ] && chown -R 0:0 "$W"
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

# Every switch off, then check_system on and slowed to a second
sed 's/^\(Tiger_\(Check\|Run\|Deb\)_[A-Za-z0-9_]*\)=.*/\1=N/' "$W/tigerrc" > "$W/tigerrc.t"
echo "Tiger_Check_SYSTEM=Y" >> "$W/tigerrc.t"
chmod 600 "$W/tigerrc.t"
printf '#!/bin/sh\nsleep 1\n' > "$W/scripts/check_system"
chmod 755 "$W/scripts/check_system"
[ "`id -u`" = 0 ] && chown 0:0 "$W/scripts/check_system" "$W/tigerrc.t"

# --- piped: seconds, no carriage returns
( cd "$W" && sh ./tigris -c tigerrc.t ) > "$W/out" 2> "$W/err"; st=$?
case $st in 0|2|3|4|5) ok "piped run finishes (exit $st)";; *) bad "piped run finishes (exit $st)";; esac
grep -q '^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]> ' "$W/out" && ok "progress lines carry seconds" || bad "progress lines carry seconds"
[ "`tr -cd '\r' < "$W/out" | wc -c`" = 0 ] && ok "no carriage returns when piped" || bad "no carriage returns when piped"

# --- on a terminal: the line spins, then finishes as the same line
printf '' | script -qec true /dev/null >/dev/null 2>&1
if [ $? -eq 0 ]; then
  ( cd "$W" && script -qec "sh ./tigris -c tigerrc.t" /dev/null ) > "$W/tty" 2> "$W/err"; st=$?
  case $st in 0|2|3|4|5) ok "terminal run finishes (exit $st)";; *) bad "terminal run finishes (exit $st)";; esac
  # a pty turns every newline into CR LF; frames are the surplus CRs
  crs=`tr -cd '\r' < "$W/tty" | wc -c`; lfs=`tr -cd '\n' < "$W/tty" | wc -c`
  [ "$crs" -gt "$lfs" ] && ok "the spinner animated ($crs CRs over $lfs lines)" || bad "the spinner animated ($crs CRs over $lfs lines)"
  grep -q '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]> ' "$W/tty" && ok "finished lines keep the timestamp" || bad "finished lines keep the timestamp"
else
  echo "SKIP: script(1) is needed for the terminal part"
fi

# --- quiet: no progress lines at all
( cd "$W" && sh ./tigris -q -c tigerrc.t ) > "$W/quiet" 2> "$W/err"
! grep -q '> .*ing\.\.\.' "$W/quiet" && ok "-q prints no progress lines" || bad "-q prints no progress lines"

[ "$fail" -eq 0 ] && echo PASS
exit $fail
