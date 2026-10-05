#!/bin/sh
#
# tests/profile_check.sh - tigerrc-quick differs from tigerrc in one line
#
# The quick profile is a full copy of tigerrc with the filesystem scan
# turned off (an unset Tiger_Check_* means "run", so profiles cannot be
# short). This fails unless the two files' assignments differ only in
# Tiger_Check_FILESYSTEM=Y vs =N. Comments and the header may differ;
# anything else names the setting that drifted.
#
# Normalization assumes values contain no ' #' (true today); the eval'd
# assignment is compared without its eval prefix.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

norm() {
  # assignments only: no full-line comments, no blanks, no trailing
  # comments, no eval prefix, no leading whitespace; then sorted
  grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' \
    | sed -e 's/[[:space:]][[:space:]]*#.*//' -e 's/[[:space:]]*$//' \
          -e 's/^[[:space:]]*//' -e 's/^eval //' | sort
}

norm "$TIGER/tigerrc" > "$W/rc.txt"
norm "$TIGER/tigerrc-quick" > "$W/quick.txt"
diff "$W/rc.txt" "$W/quick.txt" > "$W/diff.txt"; st=$?
if [ $st -eq 0 ]; then
  bad "tigerrc-quick is identical to tigerrc; it must turn the scan off"
elif [ "`grep -c '^[<>]' "$W/diff.txt"`" -eq 2 ] && \
     grep -q '^< Tiger_Check_FILESYSTEM=Y$' "$W/diff.txt" && \
     grep -q '^> Tiger_Check_FILESYSTEM=N$' "$W/diff.txt"; then
  ok "tigerrc-quick differs from tigerrc only in Tiger_Check_FILESYSTEM"
else
  bad "settings drifted between tigerrc and tigerrc-quick:"
  grep '^[<>]' "$W/diff.txt" | sed -e 's/^< /     tigerrc:       /' -e 's/^> /     tigerrc-quick: /'
  fail=1
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
