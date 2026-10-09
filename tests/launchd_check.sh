#!/bin/sh
#
# tests/launchd_check.sh - check_launchd on offline roots
#
# Three roots: loose (a world-writable daemon plist, an agent
# whose program is group-writable); tight (root-owned 644
# plists and 755 programs); and an empty root, where there is
# no launchd tree and nothing is said. Runs as a user and as
# root; the fixtures read the same for both.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
umask 022
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
run() {  # run ROOT OUTFILE: check_launchd with ROOT as the audited system
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/MacOSX/default/check_launchd ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }
empty() { [ ! -s "$1" ]; }

B=$W/bad
mkdir -p "$B/etc" "$B/Library/LaunchDaemons" "$B/Library/LaunchAgents" \
         "$B/usr/local/libexec"
cat > "$B/Library/LaunchDaemons/com.example.helper.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.example.helper</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/libexec/helper</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF
chmod 666 "$B/Library/LaunchDaemons/com.example.helper.plist"
touch "$B/usr/local/libexec/helper"
chmod 755 "$B/usr/local/libexec/helper"
cat > "$B/Library/LaunchAgents/com.example.agent.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.example.agent</string>
	<key>Program</key>
	<string>/usr/local/libexec/agent</string>
</dict>
</plist>
EOF
chmod 644 "$B/Library/LaunchAgents/com.example.agent.plist"
touch "$B/usr/local/libexec/agent"
chmod 664 "$B/usr/local/libexec/agent"
chgrp "`awk -F: '$1 != "root" { print $1; exit }' /etc/group`" "$B/usr/local/libexec/agent" 2>/dev/null || true
run "$B" "$W/out"
has '--WARN-- [lch001w]' "$W/out" &&
has 'com.example.helper.plist' "$W/out" &&
has '/usr/local/libexec/agent' "$W/out" &&
  ok "writable daemon plist, writable agent program: both" || { bad "bad"; cat "$W/out"; }

T=$W/tight
mkdir -p "$T/etc" "$T/Library/LaunchDaemons" "$T/usr/local/libexec"
cat > "$T/Library/LaunchDaemons/com.example.helper.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.example.helper</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/libexec/helper</string>
	</array>
</dict>
</plist>
EOF
chmod 644 "$T/Library/LaunchDaemons/com.example.helper.plist"
touch "$T/usr/local/libexec/helper"
chmod 755 "$T/usr/local/libexec/helper"
run "$T" "$W/out"
empty "$W/out" &&
  ok "locked plist and program: silent" || { bad "tight noisy"; cat "$W/out"; }

E=$W/emptyroot; mkdir -p "$E/etc"
run "$E" "$W/out"
empty "$W/out" &&
  ok "no launchd tree: silent" || { bad "empty noisy"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
