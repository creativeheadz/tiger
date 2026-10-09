#!/bin/sh
#
# tests/kerberos_check.sh - check_kerberos on offline roots
#
# Six roots: weak crypto (allow_weak_crypto plus a single-DES enctype)
# with a world-readable custom keytab; a clean AES-only root with a
# root-only keytab; rc4-hmac permitted; a clean main file with the weak
# enctype smuggled in through krb5.conf.d; a keytab and nothing else;
# and an empty root, where Kerberos is not in use and nothing is said.
# INFO findings only show with Tiger_Show_INFO_Msgs=Y. Runs as a user
# and as root; the fixtures read the same for both.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
cp "$W/tigerrc" "$W/tigerrc.base"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
run() {  # run ROOT OUTFILE: check_kerberos with ROOT as the audited system
  cp "$W/tigerrc.base" "$W/tigerrc"
  { echo "Tiger_Show_INFO_Msgs=Y"; } >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W TIGRIS_ROOT="$1" sh ./systems/Linux/2/check_kerberos ) 2>&1 |
  awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
  tr -s ' ' | grep '^--' | grep -v '^--CONFIG--' > "$2" || true
}
has() { grep -F -q -- "$1" "$2"; }

K=$W/weak; mkdir -p "$K/etc"
cat > "$K/etc/krb5.conf" <<'EOF'
[libdefaults]
	default_realm = EXAMPLE.COM
	allow_weak_crypto = true
	permitted_enctypes = aes256-cts des-cbc-crc
	default_keytab_name = FILE:/etc/krb5.keytab.host
[realms]
	EXAMPLE.COM = { kdc = kdc.example.com }
EOF
printf 'keytab-bytes' > "$K/etc/krb5.keytab.host"
chmod 644 "$K/etc/krb5.keytab.host"
run "$K" "$W/out"
has '--WARN-- [krb001w] Kerberos permits single-DES encryption' "$W/out" &&
has "--WARN-- [krb003w] The keytab \`/etc/krb5.keytab.host' is readable by anyone" "$W/out" &&
  ok "weak crypto plus a world-readable keytab: krb001w and krb003w" || { bad "weak"; cat "$W/out"; }

C=$W/clean; mkdir -p "$C/etc"
cat > "$C/etc/krb5.conf" <<'EOF'
[libdefaults]
	default_realm = EXAMPLE.COM
	permitted_enctypes = aes256-cts aes128-cts
EOF
printf 'keytab-bytes' > "$C/etc/krb5.keytab"
chmod 600 "$C/etc/krb5.keytab"
run "$C" "$W/out"
grep -q 'krb001w\|krb002i\|krb003w' "$W/out" && { bad "clean"; cat "$W/out"; } ||
  ok "AES-only with a root-only keytab: nothing"

R=$W/rc4; mkdir -p "$R/etc"
cat > "$R/etc/krb5.conf" <<'EOF'
[libdefaults]
	default_realm = EXAMPLE.COM
	permitted_enctypes = aes256-cts rc4-hmac
EOF
run "$R" "$W/out"
has '--INFO-- [krb002i] rc4-hmac is among the permitted enctypes' "$W/out" &&
  ! grep -q 'krb001w' "$W/out" &&
  ok "rc4-hmac permitted: only krb002i" || { bad "rc4"; cat "$W/out"; }

D=$W/dropin; mkdir -p "$D/etc/krb5.conf.d"
cat > "$D/etc/krb5.conf" <<'EOF'
[libdefaults]
	default_realm = EXAMPLE.COM
	permitted_enctypes = aes256-cts
EOF
cat > "$D/etc/krb5.conf.d/weak.conf" <<'EOF'
[libdefaults]
	allow_weak_crypto = true
EOF
run "$D" "$W/out"
has '--WARN-- [krb001w] Kerberos permits single-DES encryption' "$W/out" &&
  ok "weak crypto in a drop-in: krb001w" || { bad "dropin"; cat "$W/out"; }

O=$W/keytabonly; mkdir -p "$O/etc"
printf 'keytab-bytes' > "$O/etc/krb5.keytab"
chmod 644 "$O/etc/krb5.keytab"
run "$O" "$W/out"
has "--WARN-- [krb003w] The keytab \`/etc/krb5.keytab' is readable by anyone" "$W/out" &&
  ok "a keytab and no config: krb003w" || { bad "keytabonly"; cat "$W/out"; }

E=$W/empty; mkdir -p "$E/etc"
run "$E" "$W/out"
[ -s "$W/out" ] && { bad "empty"; cat "$W/out"; } ||
  ok "no krb5.conf and no keytab: nothing said"

[ $fail -eq 0 ] && echo "PASS"
exit $fail
