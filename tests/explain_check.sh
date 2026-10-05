#!/bin/sh
#
# tests/explain_check.sh - every finding id has an explanation
#
# Builds a fresh explain index from doc/*.txt in a scratch directory,
# enumerates every finding id the live code can emit, and fails on any
# id with no entry. Also fails on any id in a message call that is not
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
# - pathmsg $1/$2 (initdefs re-emits them verbatim). These keep the old
#   unsuffixed form (ali003, suid002); '.' as $1 marks the dead owner
#   branch and is not an id.
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
W=`mktemp -d`
trap 'rm -rf "$W"' 0
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

mkdir -p "$W/doc"
cp "$TIGER"/doc/*.txt "$W/doc/" || { bad "cannot copy doc"; exit 1; }
BASEDIR=$W sh "$TIGER/util/genmsgidx" >/dev/null 2>&1
[ -s "$W/doc/explain.idx" ] || { bad "genmsgidx built no index"; exit 1; }
awk '{print $1}' "$W/doc/explain.idx" | sort -u > "$W/explained.txt"

cd "$TIGER" || exit 1
CODE="tiger tigercron tigris-accept tigris-diff config initdefs util scripts systems/Linux/2"
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

grep -rhoE "pathmsg +[^ ]+ +[^ ]+" scripts systems/Linux/2 tiger \
  | awk '{print $2; print $3}' | grep -v '^\.$' | grep -v '\$' | sort -u > "$W/pathmsg_ids.txt"

cat "$W/shape_ids.txt" "$W/perm_ids.txt" "$W/sig_ids.txt" "$W/embed_ids.txt" "$W/pathmsg_ids.txt" \
  | sort -u > "$W/emitted.txt"

missing=`comm -23 "$W/emitted.txt" "$W/explained.txt"`
if [ -z "$missing" ]; then
  ok "`wc -l < "$W/emitted.txt" | tr -d ' '` emitted ids, every one explained"
else
  bad "ids with no explanation:"; echo "$missing" | sed 's/^/     /'
fi

# Well-formed: the id argument of message (2nd) and pathmsg (1st, 2nd).
# Dynamic ($var) ids are covered structurally above; message ids carry a
# severity suffix, pathmsg ids keep the legacy unsuffixed form.
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
deformed=$(grep -v '\$' "$W/msg_ids.txt" | grep -vE "^[a-z]+[0-9]{3}[a-z]$" || true)
if [ -z "$deformed" ]; then
  ok "every message id is well-formed"
else
  bad "malformed message ids:"; echo "$deformed" | sed 's/^/     /'
fi
deformed=$(grep -vE "^[a-z]+[0-9]{3}[a-z]?$" "$W/pathmsg_ids.txt" || true)
if [ -z "$deformed" ]; then
  ok "every pathmsg id is well-formed"
else
  bad "malformed pathmsg ids:"; echo "$deformed" | sed 's/^/     /'
fi

# Raw echo findings (--WARN-- [id]) bypass message(); their brackets
# must hold well-formed ids too.
# shellcheck disable=SC2086
grep -r "" $CODE 2>/dev/null | grep -v "^scripts/check_network:" \
  | grep -oE -- "--(WARN|FAIL|ALERT|ERROR|INFO|CONFIG)-- +\[[^]]*\]" \
  | sed -E "s/.*\[([^]]*)\].*/\1/" | sort -u > "$W/echo_ids.txt"
deformed=$(grep -v '\$' "$W/echo_ids.txt" | grep -vE "^[a-z]+[0-9]{3}[a-z]?$" || true)
if [ -z "$deformed" ]; then
  ok "every echoed finding id is well-formed"
else
  bad "malformed echoed ids:"; echo "$deformed" | sed 's/^/     /'
fi

[ $fail -eq 0 ] && echo "PASS"
exit $fail
