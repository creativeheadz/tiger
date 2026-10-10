#!/bin/sh
#
# tests/report_text_check.sh - how a finding reads in the text report
#
# Calls message() itself, as a check does, and looks at the lines it
# writes: wrapped at Tiger_Output_Width with every line after the first
# indented under the id, no line ending in a blank, a word too long for
# a line kept beside the tag (it used to leave the tag alone on its line),
# the detail on a line of its own, and backslashes in a file name written
# as they are (dash's echo read them as escapes).
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

cat > "$W/emit.sh" <<'EOF'
cd "$1" || exit 1
TIGERHOMEDIR=$1; export TIGERHOMEDIR
set --                      # config parses the command line; give it none
. ./config >/dev/null 2>&1
. ./initdefs
Tiger_JSON_File=; Tiger_Output_Width=79
long=/usr/lib/x86_64-linux-gnu/qt-default/qtchooser/a-very-long-directory-name-indeed/default.conf
message WARN test001w "" "$long is a dangling symlink."
message FAIL test002f "Detail on a line of its own, wrapped the same way when it is long enough to need it." "A message of several words that is long enough to wrap onto a second line of the report."
message WARN test003w "" 'A name with backslashes: /tmp/a\cb\nc and that is all.'
EOF
sh "$W/emit.sh" "$W" > "$W/out" 2>&1

line1=`sed -n 1p "$W/out"`
case "$line1" in
  "--WARN-- [test001w] /usr/lib/x86_64-linux-gnu/qt-default/"*) ok "a word too long for the line stays beside the tag" ;;
  *) bad "first line: $line1" ;;
esac
grep -n ' $' "$W/out" > "$W/trailing" && { bad "lines end in a blank:"; cat "$W/trailing"; } || ok "no line ends in a blank"
# every line but the tag lines is indented under the id
grep -v '^--[A-Z]*-- \[' "$W/out" | grep -v '^         [^ ]' > "$W/badindent" && [ -s "$W/badindent" ] &&
  { bad "continuation lines not indented by nine:"; cat "$W/badindent"; } || ok "continuation lines are indented under the id"
# no line past the width, but for a single word that cannot be broken
awk '{ n = ($0 ~ /^--/ ? NF - 2 : NF) } length($0) > 79 && n > 1 { print }' "$W/out" > "$W/wide"
[ -s "$W/wide" ] && { bad "lines past 79 columns:"; cat "$W/wide"; } || ok "lines fit in 79 columns"
grep -q '^--FAIL-- \[test002f\] A message of several words' "$W/out" && grep -q '^         Detail on a line of its own' "$W/out" &&
  ok "the detail starts a line of its own" || bad "detail placement"
grep -qF '/tmp/a\cb\nc and that is all.' "$W/out" && ok "backslashes in a name are written as they are" || bad "backslashes: `grep test003w -A1 "$W/out"`"

# tigexp -f (tigris -E) takes the id from the first [...] after the level:
# it took the last one, so a message holding brackets had no explanation
printf -- '--ALERT-- [suid001a] The file /usr/bin/x [setuid] is new\n' > "$W/br.txt"
( cd "$W" && sh ./tigexp -f "$W/br.txt" ) > "$W/br.out" 2>&1
grep -q '^Message ID: suid001a$' "$W/br.out" && ! grep -q 'Can not find' "$W/br.out" &&
  ok "an explanation is found for a message holding brackets" || { bad "tigexp -f with brackets"; cat "$W/br.out"; }

[ $fail -eq 0 ] && echo "PASS" || { echo "--- out"; cat "$W/out"; }
exit $fail
