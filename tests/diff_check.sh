#!/bin/sh
#
# tests/diff_check.sh - tigris-diff against two synthetic runs
#
# Two JSON Lines reports that share some findings, lose one, gain one, and
# differ in an INFO line. Checks the text, the exit status, -a, the JSON
# mode (parsed with python3 when available) and the "no files" lookup in
# a log directory.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
D=$TIGER/tigris-diff
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

mkdir -p "$W/log"
cat > "$W/log/security.report.box.261004-10:00.jsonl" <<'EOF'
{"type":"run","schema":1,"id":"run-a","tool":"tigris","version":"3.2.4","host":"box","os":"Linux","release":"7.0","arch":"x86_64","start":"2026-10-04T10:00:00Z"}
{"type":"finding","level":"WARN","id":"ssh004w","check":"check_ssh","message":"sshd: passwordauthentication is yes: passwords are accepted for login"}
{"type":"finding","level":"FAIL","id":"lin016f","check":"check_network_config","message":"The system permits source routing from incoming packets"}
{"type":"finding","level":"WARN","id":"fsys013w","check":"find_files","message":"/etc/odd \"quoted\" caf\u00e9 is a dangling symlink."}
{"type":"finding","level":"INFO","id":"cron004w","check":"check_crontabs","message":"Root crontab does not exist"}
{"type":"summary","id":"run-a","end":"2026-10-04T10:02:00Z","counts":{"ALERT":0,"FAIL":1,"WARN":2,"INFO":1,"ERROR":0}}
EOF
cat > "$W/log/security.report.box.261004-11:00.jsonl" <<'EOF'
{"type":"run","schema":1,"id":"run-b","tool":"tigris","version":"3.2.4","host":"box","os":"Linux","release":"7.0","arch":"x86_64","start":"2026-10-04T11:00:00Z"}
{"type":"finding","level":"FAIL","id":"lin016f","check":"check_network_config","message":"The system permits source routing from incoming packets"}
{"type":"finding","level":"WARN","id":"fsys013w","check":"find_files","message":"/etc/odd \"quoted\" caf\u00e9 is a dangling symlink (still)."}
{"type":"finding","level":"WARN","id":"dev004w","check":"check_devices","message":"/dev/kmsg is world readable"}
{"type":"finding","level":"INFO","id":"lin002i","check":"check_listeningprocs","message":"The process `sshd' is listening on socket 22 (TCP) on every interface."}
{"type":"summary","id":"run-b","end":"2026-10-04T11:02:00Z","counts":{"ALERT":0,"FAIL":1,"WARN":2,"INFO":1,"ERROR":0}}
EOF
A="$W/log/security.report.box.261004-10:00.jsonl"; B="$W/log/security.report.box.261004-11:00.jsonl"

sh "$D" "$A" "$B" > "$W/out.txt"; st=$?
[ $st -eq 1 ] && ok "exit 1 when something is new" || bad "exit status $st, wanted 1"
grep -q '^  new (2):' "$W/out.txt" && grep -q '+ WARN  dev004w /dev/kmsg is world readable' "$W/out.txt" && ok "the new finding is listed" || bad "new finding"
grep -q '^  resolved (2):' "$W/out.txt" && grep -q -- '- WARN  ssh004w sshd: passwordauthentication' "$W/out.txt" && ok "the resolved finding is listed" || bad "resolved finding"
grep -q 'unchanged: 1 (INFO not compared' "$W/out.txt" && ok "one unchanged, INFO left out" || bad "unchanged count"
grep -q "$(printf '/etc/odd "quoted" caf\351 is a dangling symlink (still)')" "$W/out.txt" && ok "message with escapes decoded for display" || bad "decoding"
grep -q 'Tigris diff: box 2026-10-04T10:00:00Z -> box 2026-10-04T11:00:00Z' "$W/out.txt" && ok "header names host and times" || bad "header"
grep -q 'cron004w\|lin002i' "$W/out.txt" && bad "INFO leaked into the default diff" || ok "INFO not in the default diff"

sh "$D" -a "$A" "$B" > "$W/all.txt"
grep -q '^  new (3):' "$W/all.txt" && grep -q 'lin002i' "$W/all.txt" && grep -q -- '- INFO  cron004w' "$W/all.txt" && ok "-a compares INFO too" || bad "-a"

sh "$D" "$B" "$B" > "$W/same.txt"; st=$?
[ $st -eq 0 ] && grep -q 'new (0)' "$W/same.txt" && ok "a run against itself: nothing new, exit 0" || bad "self diff"

( cd "$W" && sh "$D" ) > "$W/auto.txt"
grep -q 'dev004w' "$W/auto.txt" && grep -q 'ssh004w' "$W/auto.txt" && ok "no arguments: the two newest runs in ./log" || bad "auto lookup"
( cd "$W" && sh "$D" "$B" ) > "$W/one.txt"
grep -q 'dev004w' "$W/one.txt" && ok "one argument: that run against the one before" || bad "one-argument lookup"

sh "$D" -j "$A" "$B" > "$W/diff.json"
if command -v python3 >/dev/null; then
  python3 - "$W/diff.json" <<'EOF' && ok "-j is one JSON object with run records and raw findings" || bad "-j"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["type"] == "diff" and d["from"]["id"] == "run-a" and d["to"]["id"] == "run-b"
assert [f["id"] for f in d["new"]] == ["fsys013w", "dev004w"] and [f["id"] for f in d["resolved"]] == ["ssh004w", "fsys013w"]
assert d["unchanged"] == 1
assert d["resolved"][0]["check"] == "check_ssh"
EOF
else
  grep -q '"type":"diff"' "$W/diff.json" && ok "-j writes a diff object (python3 absent, not parsed)" || bad "-j"
fi

[ $fail -eq 0 ] && echo "PASS" || { echo "--- out.txt"; cat "$W/out.txt"; }
exit $fail
