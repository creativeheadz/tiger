#!/bin/sh
#
# tests/smoke.sh - a full Tiger run from a root-owned copy of this tree
#
# Checks that tiger writes a report, exits with the worst level in it,
# runs every check it was asked to (no misc024e/misc025e/misc005e), that
# every id in the JSON has an explanation, and prints how long it took and
# what it found. Run as root.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}

[ "`id -u`" = 0 ] || { echo "SKIP: must run as root"; exit 2; }

W=`mktemp -d`
trap 'rm -rf "$W"' 0
# log/ and run/ stay behind: an old report there would be checked instead
# of this run's
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/log" "$W/run"
chown -R 0:0 "$W"
cd "$W"

start=`date +%s`
sh ./tiger > "$W/stdout" 2> "$W/stderr"
status=$?
end=`date +%s`

fail=0
report=`ls "$W"/log/security.report.* 2>/dev/null | head -1`
[ -n "$report" ] && echo "ok   report written: ${report#$W/}" || { echo "FAIL no report in log/"; fail=1; }
if [ -n "$report" ]; then
  want=0
  for l in ERROR:2 WARN:3 FAIL:4 ALERT:5; do grep -q "^--${l%:*}-- " "$report" && want=${l#*:}; done
  [ "$status" -eq "$want" ] && echo "ok   tiger exited $status, the worst level in its report" || { echo "FAIL tiger exited $status, the report says $want"; fail=1; }
fi

if [ -n "$report" ]; then
  skipped=`grep -c 'misc024e\|misc025e\|misc005e' "$report"`
  [ "$skipped" -eq 0 ] && echo "ok   no check was skipped" || {
    echo "FAIL $skipped checks were skipped:"; grep 'misc024e\|misc025e\|misc005e' "$report" | head; fail=1; }
  echo "---  `expr $end - $start`s, `wc -l < "$report"` report lines"
  grep -oE -- '--(FAIL|WARN|ALERT|INFO|ERROR)--' "$report" | sort | uniq -c | sed 's/^/     /'
  echo "---  by code"
  grep -oE '\[[a-z]+[0-9]{3}[a-z]\]' "$report" | sort | uniq -c | sort -rn | head -15 | sed 's/^/     /'
fi
jsonl=`ls "$W"/log/security.report.*.jsonl 2>/dev/null | head -1`
if [ -n "$jsonl" ] && command -v python3 >/dev/null; then
  python3 - "$jsonl" "$report" <<'EOF' && echo "ok   JSON Lines report parses and matches the text" || { echo "FAIL JSON Lines report"; fail=1; }
import json, re, sys
recs = [json.loads(l) for l in open(sys.argv[1], encoding="ascii") if l.strip()]
assert recs[0]["type"] == "run" and recs[-1]["type"] == "summary", (recs[0], recs[-1])
finds = [r for r in recs if r["type"] == "finding"]
text = open(sys.argv[2], encoding="latin-1").read()
# ERROR lines from the init helpers are plain echoes and never reach the JSON
shown = re.findall(r"--(ALERT|FAIL|WARN)-- \[([a-z]+[0-9]{3}[a-z])\]", text)
json_shown = [(r["level"], r["id"]) for r in finds if r["level"] in ("ALERT", "FAIL", "WARN")]
assert sorted(shown) == sorted(json_shown), (len(shown), len(json_shown))
assert recs[-1]["counts"]["WARN"] == sum(1 for r in finds if r["level"] == "WARN")
EOF
elif [ -z "$jsonl" ]; then
  echo "FAIL no JSON Lines report in log/"; fail=1
fi
# Runtime side of the every-id-explained rule: the source scan in
# tests/explain_check.sh cannot see ids built from variables, but a real
# run shows them. Every finding needs its meta/ID file, and so carries a
# category in the JSON.
if [ -n "$jsonl" ]; then
  if command -v python3 >/dev/null; then
    python3 - "$jsonl" "$W/meta" <<'EOF' > "$W/ids.out" 2>&1; st=$?
import json, os, sys
explained = set(os.listdir(sys.argv[2]))
emitted, nocat = set(), set()
with open(sys.argv[1], encoding="ascii") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        rec = json.loads(line)
        if rec["type"] == "finding":
            emitted.add(rec["id"])
            if "category" not in rec:
                nocat.add(rec["id"])
missing = sorted((emitted - explained) | nocat)
if missing:
    print("\n".join(missing))
    sys.exit(1)
print("ok   every finding id in the JSON has a meta file and a category (%d ids)" % len(emitted))
EOF
    if [ $st -eq 0 ]; then cat "$W/ids.out"
    else echo "FAIL finding ids without a meta file or a category:"; sed 's/^/     /' "$W/ids.out"; fail=1; fi
  else
    echo "skip id-explanation check (python3 not installed)"
  fi
fi
if [ -n "$jsonl" ]; then
  sh "$TIGER/tests/schema_check.sh" "$jsonl" > "$W/schema.out" 2>&1; st=$?
  if [ $st -eq 0 ]; then grep '^ok   .*records validate' "$W/schema.out"
  elif [ $st -eq 2 ]; then echo "skip JSON schema validation (jsonschema for Python not installed)"
  else echo "FAIL JSON report does not match the schema:"; grep -v '^ok' "$W/schema.out" | head -8; fail=1; fi
fi
if [ -s "$W/stderr" ]; then
  echo "---  stderr"
  sort "$W/stderr" | uniq -c | sort -rn | head -10 | sed 's/^/     /'
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
