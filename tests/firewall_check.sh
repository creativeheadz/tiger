#!/bin/sh
#
# tests/firewall_check.sh - check_firewall against real rulesets
#
# The fixtures in tests/fixtures/firewall are "nft list ruleset" and
# "iptables -S INPUT" output captured from containers with their own
# network namespace (docker run --cap-add NET_ADMIN): nothing loaded, ufw
# enabled on Ubuntu 24.04, firewalld started on Fedora, and nftables
# configurations loaded with nft 1.1.3 on Debian stable. Each run feeds one
# of them through Tiger_NFT_Cmd and checks what is concluded for IPv4 and
# IPv6.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
FX="$TIGER/tests/fixtures/firewall"
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# A /proc and /sys of our own: IPv6 on, no legacy iptables tables
mkdir -p "$W/sys/proc/net" "$W/sys/proc/sys/net/ipv6/conf/all" "$W/sys/sys/module/nf_tables"
: > "$W/sys/proc/net/if_inet6"
echo 0 > "$W/sys/proc/sys/net/ipv6/conf/all/disable_ipv6"
cp "$W/tigerrc" "$W/tigerrc.base"

# go NFT-COMMAND [setting=value ...]: run the check, findings to $W/out
go() {
  cp "$W/tigerrc.base" "$W/tigerrc"
  {
    echo "Tiger_NFT_Cmd='$1'"
    echo "Tiger_Sysctl_Root='$W/sys'"
    echo "Tiger_Firewall_Frontends=''"
    echo "Tiger_Show_INFO_Msgs=Y"
    shift
    for s; do echo "$s"; done
  } >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh ./systems/Linux/2/check_firewall ) 2>&1 |
    # one line per finding: join the wrapped lines
    awk '/^--/ { if (l != "") print l; l = $0; next } /^ / { sub(/^ +/, " "); l = l $0; next } { if (l != "") print l; l = "" } END { if (l != "") print l }' |
    tr -s ' ' > "$W/out"
}
has()   { grep -F -q -- "$1" "$W/out"; }
count() { grep -c -- "$1" "$W/out"; }
# expect FIXTURE "v4 text" "v6 text" what: each text is what must appear
expect() {
  go "cat $FX/$1"
  if has "$2" && has "$3"; then ok "$4"; else bad "$4"; sed 's/^/     /' "$W/out"; fi
}

expect none.nft \
  '--WARN-- [fire001w] Incoming IPv4 traffic is not denied by default: no input chain drops what it does not accept. No chain on the input hook filters IPv4' \
  '--WARN-- [fire002w] Incoming IPv6 traffic is not denied by default' \
  "nothing loaded: WARN for IPv4 and IPv6"
expect ufw.nft \
  '--INFO-- [fire003i] Incoming IPv4 traffic is denied by default (nftables ip filter INPUT: policy drop).' \
  '--INFO-- [fire003i] Incoming IPv6 traffic is denied by default (nftables ip6 filter INPUT: policy drop).' \
  "ufw enabled (Ubuntu 24.04, iptables-nft): denied for both"
expect firewalld.nft \
  '--INFO-- [fire003i] Incoming IPv4 traffic is denied by default (nftables inet firewalld filter_INPUT: ends with an unconditional reject).' \
  '--INFO-- [fire003i] Incoming IPv6 traffic is denied by default (nftables inet firewalld filter_INPUT: ends with an unconditional reject).' \
  "firewalld (Fedora): policy accept, but the chain ends with a reject"
expect inet-drop.nft \
  'Incoming IPv4 traffic is denied by default (nftables inet filter input: policy drop).' \
  'Incoming IPv6 traffic is denied by default (nftables inet filter input: policy drop).' \
  "an inet chain with policy drop covers both families"
expect final-drop.nft \
  'IPv4 traffic is denied by default (nftables inet filter input: ends with an unconditional drop).' \
  'IPv6 traffic is denied by default (nftables inet filter input: ends with an unconditional drop).' \
  "a last rule 'counter packets 0 bytes 0 drop' is a default-deny"
expect log-reject.nft \
  'IPv4 traffic is denied by default (nftables ip filter input: ends with an unconditional drop).' \
  'IPv6 traffic is denied by default (nftables ip6 filter input: ends with an unconditional reject).' \
  "log and counter before the verdict, a set in the table, reject with an ICMPv6 type"
expect v4-only.nft \
  'IPv4 traffic is denied by default (nftables ip filter input: policy drop).' \
  '--WARN-- [fire002w] Incoming IPv6 traffic is not denied by default: no input chain drops what it does not accept. No chain on the input hook filters IPv6' \
  "an ip-family chain protects IPv4 only, and IPv6 is reported open"
expect conditional.nft \
  '[fire001w] Incoming IPv4 traffic is not denied by default: no input chain drops what it does not accept. Input chains: nftables inet filter input: policy accept.' \
  '[fire002w] Incoming IPv6 traffic is not denied by default' \
  "drops that only match some traffic are not a default-deny"
expect debian-default.nft \
  'Input chains: nftables inet filter input: policy accept.' \
  '[fire002w]' \
  "Debian's default nftables.conf (chains with no policy) is open"
expect forward-only.nft \
  '[fire001w] Incoming IPv4 traffic is not denied by default' \
  '[fire002w] Incoming IPv6 traffic is not denied by default' \
  "a forward chain with policy drop does not protect the host"

# Legacy iptables, read beside an empty nftables ruleset
go "cat $FX/none.nft" "Tiger_IPT_Legacy_Cmd='cat $FX/legacy-drop.ipt'"
has 'Incoming IPv4 traffic is denied by default (iptables-legacy INPUT: policy DROP).' && has '[fire002w]' &&
  ok "legacy iptables INPUT policy DROP counts for IPv4, not IPv6" || { bad "legacy iptables"; cat "$W/out"; }

# IPv6 switched off: nothing to say about it
echo 1 > "$W/sys/proc/sys/net/ipv6/conf/all/disable_ipv6"
go "cat $FX/none.nft"
has '[fire001w]' && [ "`count fire002w`" = 0 ] && ok "IPv6 disabled: no IPv6 finding" || { bad "IPv6 disabled"; cat "$W/out"; }
echo 0 > "$W/sys/proc/sys/net/ipv6/conf/all/disable_ipv6"

# The ruleset cannot be read (not root): an ERROR, and no guess
printf '#!/bin/sh\necho "Error: Operation not permitted" >&2\nexit 1\n' > "$W/nft-denied"
go "sh $W/nft-denied"
has '--ERROR-- [fire004e] The nftables ruleset could not be read' && has 'Error: Operation not permitted' &&
  [ "`count 'fire00[123]'`" = 0 ] && ok "an unreadable ruleset is an ERROR (fire004e) with nft's reason, not a WARN" || { bad "unreadable ruleset"; cat "$W/out"; }

# The advice names what is installed
go "cat $FX/none.nft" "Tiger_Firewall_Frontends='ufw'"
has "ufw is installed: 'ufw enable' turns on its default-deny policy." && ok "with ufw installed, the advice is 'ufw enable'" || { bad "ufw advice"; cat "$W/out"; }
go "cat $FX/none.nft" "Tiger_Firewall_Frontends='firewalld'"
has "firewalld is installed: 'systemctl enable --now firewalld'" && ok "with firewalld installed, the advice is to start it" || { bad "firewalld advice"; cat "$W/out"; }

[ $fail -eq 0 ] && echo "PASS"
exit $fail
