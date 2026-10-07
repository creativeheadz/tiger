#!/bin/sh
#
# tests/ssh_check.sh - check_ssh against canned sshd -T output
#
# Feeds the check a fixture in which every setting is wrong, then one in
# which every setting is right, through Tiger_SSHD_Cmd. Needs no root and
# no sshd.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"

cat > "$W/bad.txt" <<FIX
passwordauthentication yes
permitrootlogin yes
permitemptypasswords yes
x11forwarding yes
maxauthtries 6
usepam no
kbdinteractiveauthentication yes
logingracetime 120
hostbasedauthentication yes
ignorerhosts no
permituserenvironment yes
loglevel quiet
ciphers aes128-cbc,aes256-ctr,3des-cbc
macs hmac-md5,hmac-sha2-256-etm@openssh.com,hmac-sha1-96
kexalgorithms diffie-hellman-group1-sha1,curve25519-sha256
FIX
cat > "$W/good.txt" <<FIX
passwordauthentication no
permitrootlogin prohibit-password
permitemptypasswords no
x11forwarding no
maxauthtries 4
usepam yes
kbdinteractiveauthentication no
logingracetime 60
hostbasedauthentication no
ignorerhosts yes
permituserenvironment no
loglevel verbose
ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
macs hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
kexalgorithms curve25519-sha256,diffie-hellman-group16-sha512
FIX

run()
{
  echo "Tiger_SSHD_Cmd='cat $1'" >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh scripts/check_ssh 2>&1 )
  sed -i '$d' "$W/tigerrc"
}

fail=0
run "$W/bad.txt" > "$W/bad.out"
for code in ssh004w ssh006f ssh007f ssh008w ssh009w ssh010w ssh011w ssh012w ssh013w ssh014w ssh015w ssh016w ssh017w ssh018w ssh019w
do
  if grep -q "\[$code\]" "$W/bad.out"; then echo "ok   $code reported"; else echo "FAIL $code missing"; fail=1; fi
done
# the weak-algorithm messages must name the weak ones and not the good ones
grep -A1 'ssh017w' "$W/bad.out" | tr -d '\n' | grep -q 'aes128-cbc' && ! grep -A1 'ssh017w' "$W/bad.out" | tr -d '\n' | grep -q 'aes256-ctr' \
  && echo "ok   ssh017w names only the weak cipher" || { echo "FAIL ssh017w cipher list"; fail=1; }

run "$W/good.txt" > "$W/good.out"
if grep -q -- '--\(WARN\|FAIL\|ALERT\)--' "$W/good.out"; then
  echo "FAIL good fixture still reported:"; grep -- '--' "$W/good.out" | head; fail=1
else
  echo "ok   nothing reported for the good fixture"
fi
[ $fail -eq 0 ] && echo "PASS" || { echo "--- bad.out"; cat "$W/bad.out"; }
exit $fail
