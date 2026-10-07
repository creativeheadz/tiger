#!/bin/sh
#
# tests/explain_check.sh - every finding id has its metadata, and only those
#
# Enumerates every finding id the live code can emit and fails on any id
# with no meta/ID file, and on any file for an id nothing emits. Each file
# is checked against doc/metadata.md: known keys, the required ones
# present, a severity that covers every level the code reports the id at,
# a known category, and a Check list that names exactly the scripts the
# id appears in. Also fails on any id in a message call that is not
# well-formed, so the next tigxxxx is caught here instead of in a report.
#
# What "emitted" covers, and why each source looks the way it does:
# - literal ids anywhere in the live shell (message calls, pathmsg
#   arguments, aide/integrit exp= values, raw echo findings). Full-line
#   comments are stripped first: changelog comments name ids of checks
#   removed in 2003.
# - file_access_list: check_perms builds perm<OwnID|GrpID><a|f|w> from
#   its data columns, so the data is parsed, not scanned.
# - signatures: check_signatures takes its id from the data's msgid
#   column (today every line says '.', i.e. no real id).
# - check_embed: emits embed001..embed004 with $l, which is 'w' except
#   for INFO ('i'), so both suffixes are enumerated.
# - pathmsg $1/$2 are ids without their last letter, which pathmsg adds
#   from the level: $1 (not owned by) becomes w or i, $2 (writable by)
#   f, w or i, so ali003 is ali003w and ali003i. '.' as $1 marks the
#   dead owner branch and is not an id.
# Out of scope, each for a reason stated once here:
# - scripts/check_network: perl, undispatched (commented out in tiger).
# - systems/Linux/0 and 1: kernel 0.x/1.x, unreachable; systems/default
#   is the non-Linux fallback (Linux-first: REL is always 2 or default).
# - data files under systems/Linux/2 in the shape scan: md5 hashes
#   contain id-shaped fragments; the two that build ids are parsed above.
# - c/: the helpers hash and resolve paths, they emit no findings.
# - audit/: standalone scripts for other systems, not part of a run.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
# Bytes, not characters: some scripts are Latin-1, and sort and comm
# must agree on one order
LC_ALL=C; export LC_ALL
W=`mktemp -d`
trap 'rm -rf "$W"' 0
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

cd "$TIGER" || exit 1
ls meta | sort > "$W/explained.txt"
[ -s "$W/explained.txt" ] || { bad "no meta files"; exit 1; }
CODE="tiger tigris tigercron tigris-accept tigris-diff config initdefs util scripts systems/Linux/2"
# shellcheck disable=SC2086
grep -r "" $CODE 2>/dev/null \
  | grep -v "^[^:]*:[ 	]*#" \
  | grep -v "^scripts/check_network:" \
  | grep -v "systems/Linux/2/\(embedlist\|facl.strict\|file_access_list\|rel_file_exp_list\|rh7.3.baseline\|services\|services.save\|sgid_list\|signatures\|suid_list\):" \
  | grep -oE "[a-z]+[0-9]{3}[a-z]" | sort -u > "$W/shape_ids.txt"

awk 'NF>=17 && $15 ~ /^[AFW.]$/ && $16 ~ /^[0-9][0-9][0-9]$/ {
  l="w"; if ($15=="A") l="a"; if ($15=="F") l="f";
  print "perm" $16 l; print "perm" $17 l
}' systems/Linux/2/file_access_list | sort -u > "$W/perm_ids.txt"

awk '!/^#/ && NF>=2 && $2 ~ /^[a-z]+[0-9][0-9][0-9][a-z]$/ {print $2}' \
  systems/Linux/2/signatures | sort -u > "$W/sig_ids.txt"

grep -hoE "embed00[0-9]\\\$l" scripts/sub/check_embed | sort -u | sed 's/\$l//' > "$W/embed_base.txt"
: > "$W/embed_ids.txt"
while read -r b; do echo "${b}w"; echo "${b}i"; done < "$W/embed_base.txt" > "$W/embed_ids.txt"

grep -rh "" scripts systems/Linux/2 tiger | grep -v "^[ 	]*#" | grep -oE "pathmsg +[^ ]+ +[^ ]+" > "$W/pathmsg_calls.txt"
awk '{print $2; print $3}' "$W/pathmsg_calls.txt" | grep -v '^\.$' | grep -v '\$' | sort -u > "$W/pathmsg_bases.txt"
awk '$2 != "." { print $2 "w"; print $2 "i" } { print $3 "f"; print $3 "w"; print $3 "i" }' "$W/pathmsg_calls.txt" \
  | sort -u > "$W/pathmsg_ids.txt"

cat "$W/shape_ids.txt" "$W/perm_ids.txt" "$W/sig_ids.txt" "$W/embed_ids.txt" "$W/pathmsg_ids.txt" \
  | sort -u > "$W/emitted.txt"

missing=`comm -23 "$W/emitted.txt" "$W/explained.txt"`
if [ -z "$missing" ]; then
  ok "`wc -l < "$W/emitted.txt" | tr -d ' '` emitted ids, every one with a meta file"
else
  bad "ids with no meta file:"; echo "$missing" | sed 's/^/     /'
fi
orphans=`comm -13 "$W/emitted.txt" "$W/explained.txt"`
if [ -z "$orphans" ]; then
  ok "no meta file for an id nothing emits"
else
  bad "meta files for ids nothing emits (remove them):"; echo "$orphans" | sed 's/^/     /'
fi

# What the code says about each id: "id script" for every script it
# appears in, and "id LEVEL" for every level a message call or a raw
# --LEVEL-- line gives it (pathmsg adds the level's letter: w or i to its
# owner id, f, w or i to its access id)
# shellcheck disable=SC2086
grep -r "" $CODE 2>/dev/null | grep -v "^[^:]*:[ 	]*#" | grep -v "^scripts/check_network:" \
  | grep -v "systems/Linux/2/\(embedlist\|facl.strict\|file_access_list\|rel_file_exp_list\|rh7.3.baseline\|services\|services.save\|sgid_list\|signatures\|suid_list\):" \
  | awk '{
      file = $0; sub(/:.*/, "", file); n = split(file, p, "/"); base = p[n]
      line = $0; sub(/^[^:]*:/, "", line)
      rest = line
      while (match(rest, /[a-z]+[0-9][0-9][0-9][a-z]?/)) {
        print substr(rest, RSTART, RLENGTH), "S", base
        rest = substr(rest, RSTART + RLENGTH)
      }
      nf = split(line, w, /[ \t;&|{(]+/)
      for (i = 1; i < nf; i++) {
        lv = w[i + 1]; id = w[i + 2]; gsub(/"/, "", lv); gsub(/"/, "", id)
        if (w[i] == "message" && lv ~ /^(ALERT|FAIL|WARN|INFO|ERROR|CONFIG)$/ && id ~ /^[a-z]+[0-9][0-9][0-9][a-z]?$/)
          print id, "L", lv
        if (w[i] == "pathmsg") {
          if (lv != ".") { print lv "w", "L", "WARN"; print lv "i", "L", "INFO"; print lv "w", "S", base; print lv "i", "S", base }
          print id "f", "L", "FAIL"; print id "w", "L", "WARN"; print id "i", "L", "INFO"
          print id "f", "S", base; print id "w", "S", base; print id "i", "S", base
        }
      }
      rest = line
      while (match(rest, /--(ALERT|FAIL|WARN|INFO|ERROR|CONFIG)-- +\[[a-z]+[0-9][0-9][0-9][a-z]?\]/)) {
        m = substr(rest, RSTART, RLENGTH); lv = m; sub(/^--/, "", lv); sub(/--.*/, "", lv)
        id = m; sub(/.*\[/, "", id); sub(/\]/, "", id)
        print id, "L", lv
        rest = substr(rest, RSTART + RLENGTH)
      }
    }' | sort -u > "$W/code.txt"

# Each file against doc/metadata.md and what the code says
problems=`awk -v code="$W/code.txt" '
  BEGIN {
    while ((getline l < code) > 0) {
      split(l, f, " ")
      if (f[2] == "S") scripts[f[1]] = scripts[f[1]] " " f[3]
      else levels[f[1]] = levels[f[1]] " " f[3]
    }
    split("Id Severity Category Check Fix References Controls", k, " "); for (i in k) known[k[i]] = 1
    split("accounts boot cron filesystem firewall integrity intrusion kernel logging network packages services ssh tigris", k, " "); for (i in k) cats[k[i]] = 1
    split("ALERT FAIL WARN INFO ERROR CONFIG", k, " "); for (i in k) lvls[k[i]] = 1
    suf["a"] = "ALERT"; suf["f"] = "FAIL"; suf["w"] = "WARN"; suf["i"] = "INFO"; suf["e"] = "ERROR"; suf["c"] = "CONFIG"
  }
  function done_file() {
    if (file == "") return
    id = file; sub(/.*\//, "", id)
    if (v["Id"] != id) print id ": Id is \"" v["Id"] "\""
    if (v["Severity"] == "") print id ": no Severity"
    if (!(v["Category"] in cats)) print id ": unknown Category \"" v["Category"] "\""
    if (v["Check"] == "") print id ": no Check"
    if (body == 0) print id ": no explanation"
    split("", sev); n = split(v["Severity"], s, /, /)
    for (i = 1; i <= n; i++) { if (!(s[i] in lvls)) print id ": unknown level \"" s[i] "\""; sev[s[i]] = 1 }
    last = substr(id, length(id))
    if ((last in suf) && !(suf[last] in sev)) print id ": Severity leaves out " suf[last] ", which its last letter names"
    n = split(levels[id], s, " ")
    for (i = 1; i <= n; i++) if (!(s[i] in sev)) print id ": the code reports it as " s[i] ", not in Severity"
    if (v["Check"] != "any" && id !~ /^(perm|embed)/) {
      split("", want); split("", have)
      n = split(scripts[id], s, " "); for (i = 1; i <= n; i++) want[s[i]] = 1
      n = split(v["Check"], s, " "); for (i = 1; i <= n; i++) have[s[i]] = 1
      for (c in want) if (!(c in have)) print id ": appears in " c ", not in Check"
      for (c in have) if (!(c in want)) print id ": Check names " c ", where it does not appear"
    }
  }
  FNR == 1 { done_file(); file = FILENAME; inhead = 1; body = 0; split("", v) }
  inhead && /^$/ { inhead = 0; next }
  inhead {
    key = $0; sub(/:.*/, "", key); val = $0; sub(/^[^:]*: ?/, "", val)
    if (!(key in known)) print FILENAME ": unknown key \"" key "\""
    else if (key in v) print FILENAME ": " key " twice"
    v[key] = val; next
  }
  NF { body = 1 }
  END { done_file() }
' meta/*`
if [ -z "$problems" ]; then
  ok "every meta file is well-formed and agrees with the code"
else
  bad "meta files:"; echo "$problems" | sed 's/^/     /'
fi

# Well-formed: the id argument of message (2nd) and pathmsg (1st, 2nd).
# Dynamic ($var) ids are covered structurally above; message ids carry a
# severity suffix, pathmsg is given ids without one and adds it.
# shellcheck disable=SC2086
grep -r "" $CODE 2>/dev/null | grep -v "^[^:]*:[ 	]*#" | grep -v "^scripts/check_network:" \
  | cut -d: -f2- | awk '{
      for (i = 1; i <= NF - 2; i++) {
        if ($i == "message" || $i ~ /[;&|{(]message$/) {
          lvl = $(i+1); id = $(i+2)
          gsub(/"/, "", lvl); gsub(/"/, "", id)
          if (lvl ~ /^(ALERT|FAIL|WARN|INFO|ERROR|CONFIG)$/ || lvl ~ /^\$/) print id
          break
        }
      }
    }' | sort -u > "$W/msg_ids.txt"
# The shape doc/tigris-report.schema.json requires of an id
deformed=$(grep -v '\$' "$W/msg_ids.txt" | grep -vE "^[a-z]{3,7}[0-9]{3}[a-z]$" || true)
if [ -z "$deformed" ]; then
  ok "every message id is well-formed"
else
  bad "malformed message ids:"; echo "$deformed" | sed 's/^/     /'
fi
deformed=$( { grep -vE "^[a-z]{3,7}[0-9]{3}$" "$W/pathmsg_bases.txt"; grep -vE "^[a-z]{3,7}[0-9]{3}[a-z]$" "$W/pathmsg_ids.txt"; } || true)
if [ -z "$deformed" ]; then
  ok "every pathmsg id is well-formed (given without its letter, which pathmsg adds)"
else
  bad "malformed pathmsg ids:"; echo "$deformed" | sed 's/^/     /'
fi

# Raw echo findings (--WARN-- [id]) bypass message(); their brackets
# must hold well-formed ids too.
# shellcheck disable=SC2086
grep -r "" $CODE 2>/dev/null | grep -v "^scripts/check_network:" \
  | grep -oE -- "--(WARN|FAIL|ALERT|ERROR|INFO|CONFIG)-- +\[[^]]*\]" \
  | sed -E "s/.*\[([^]]*)\].*/\1/" | sort -u > "$W/echo_ids.txt"
deformed=$(grep -v '\$' "$W/echo_ids.txt" | grep -vE "^[a-z]{3,7}[0-9]{3}[a-z]?$" || true)
if [ -z "$deformed" ]; then
  ok "every echoed finding id is well-formed"
else
  bad "malformed echoed ids:"; echo "$deformed" | sed 's/^/     /'
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
