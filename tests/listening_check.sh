#!/bin/sh
#
# tests/listening_check.sh - check_listeningprocs against lsof fixtures
#
# Two runs of lsof -F output that differ only in the ports the kernel gave
# out (UDP clients such as browsers and Syncthing hold several, and they
# change every run). The findings must be the same in both, with the ports
# in the detail, so tigris --since does not report them as new each time.
# Fixed ports keep their own finding, loopback and connected sockets are
# left out, and a root listener on every interface is a WARN only, not a
# WARN and an INFO.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run -cf - . ) | ( cd "$W" && tar -xf - )
mkdir -p "$W/run" "$W/log"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# lsof -FpPcnLt: p pid, c command, L login, t type, P protocol, n address
fixture() {  # fixture FILE syncthing-port syncthing-port brave-port root-port
cat > "$1" <<EOF
p1
csshd
Lroot
tIPv4
PTCP
n*:22
p2
csyncthing
Landrei
tIPv4
PUDP
n*:21027
tIPv4
PUDP
n*:$2
tIPv4
PUDP
n*:$3
tIPv4
PTCP
n192.168.1.142:56176->81.150.150.132:443
p3
cbrave
Landrei
tIPv4
PUDP
n192.168.1.142:$4
p4
cnode
Landrei
tIPv4
PTCP
n*:3000
p5
csystemd-resolve
Lsystemd-resolve
tIPv4
PUDP
n127.0.0.53:53
p6
cdhclient
Lroot
tIPv4
PUDP
n*:$5
EOF
}
fixture "$W/a.lsof" 41402 56706 47778 44444
fixture "$W/b.lsof" 37201 58861 39000 33333

mkdir -p "$W/sys/proc/sys/net/ipv4"
printf '32768\t60999\n' > "$W/sys/proc/sys/net/ipv4/ip_local_port_range"

cp "$W/tigerrc" "$W/tigerrc.base"
go() {  # go LSOF-FIXTURE JSON-OUT
  cp "$W/tigerrc.base" "$W/tigerrc"
  {
    echo "Tiger_LSOF_Cmd='cat $1'"
    echo "Tiger_Sysctl_Root='$W/sys'"
    echo "Tiger_JSON_File='$2'"
    echo "Tiger_Listening_ValidUsers='root'"
    echo "Tiger_Listening_Every=Y"
  } >> "$W/tigerrc"
  ( cd "$W" && TIGERHOMEDIR=$W sh ./systems/Linux/2/check_listeningprocs ) > "$W/out" 2>&1
}

go "$W/a.lsof" "$W/a.jsonl"
A="$W/a.jsonl"
has() { grep -F -q "$1" "$A"; }

has '"level":"WARN","id":"lin002i","check":"check_listeningprocs","message":"The process `sshd'"'"' is listening on socket 22 (TCP) on every interface."' &&
  ok "root listener on every interface: lin002i WARN" || bad "sshd lin002i WARN"
[ "`grep -c 'sshd' "$A"`" = 1 ] && ok "and only that, no INFO copy of it" || bad "sshd reported `grep -c sshd "$A"` times"
has '"id":"lin003w","check":"check_listeningprocs","message":"The process `syncthing'"'"' is listening on socket 21027 (UDP on every interface) is run by andrei."' &&
  ok "a fixed port keeps its own finding" || bad "syncthing 21027"
has '"message":"The process `syncthing'"'"' is listening on ephemeral ports (UDP on every interface) is run by andrei.","detail":"Ports 41402, 56706; the kernel gives out 32768-60999, so they change from run to run."' &&
  ok "two ephemeral ports of one process: one finding, the ports in the detail" || bad "syncthing ephemeral"
has '"message":"The process `brave'"'"' is listening on ephemeral ports (UDP on 192.168.1.142 interface) is run by andrei.","detail":"Port 47778;' &&
  ok "one ephemeral port on an address: Port, singular" || bad "brave ephemeral"
has '"message":"The process `node'"'"' is listening on socket 3000 (TCP on every interface) is run by andrei."' &&
  ok "a TCP listener on a fixed port, user process: lin003w with the port" || bad "node 3000"
has '"level":"WARN","id":"lin002i","check":"check_listeningprocs","message":"The process `dhclient'"'"' is listening on ephemeral ports (UDP) on every interface.","detail":"Port 44444;' &&
  ok "a root process on an ephemeral port: lin002i, folded the same way" || bad "dhclient lin002i"
grep -q 'systemd-resolve\|:443\|56176' "$A" && bad "loopback or a connected socket was reported" || ok "loopback and connected sockets are left out"

# The same processes on other ephemeral ports: nothing new, nothing resolved
go "$W/b.lsof" "$W/b.jsonl"
sh "$W/tigris-diff" "$W/a.jsonl" "$W/b.jsonl" > "$W/diff.txt"; st=$?
[ $st -eq 0 ] && grep -q '^  new (0):' "$W/diff.txt" && grep -q '^  resolved (0):' "$W/diff.txt" &&
  ok "two runs that differ only in ephemeral ports compare unchanged" || bad "diff of the two runs: `cat "$W/diff.txt"`"
grep -q '"detail":"Ports 37201, 58861;' "$W/b.jsonl" && ok "the second run's detail has its own ports" || bad "b detail"

# The range comes from the kernel: narrower, and 56706 is a port of its own
printf '40000\t50000\n' > "$W/sys/proc/sys/net/ipv4/ip_local_port_range"
go "$W/a.lsof" "$W/c.jsonl"
grep -F -q 'syncthing'"'"' is listening on ephemeral ports (UDP on every interface) is run by andrei.","detail":"Port 41402; the kernel gives out 40000-50000' "$W/c.jsonl" &&
  grep -F -q 'syncthing'"'"' is listening on socket 56706 (UDP' "$W/c.jsonl" &&
  ok "the range is read from ip_local_port_range" || bad "range from the kernel: `grep syncthing "$W/c.jsonl"`"

[ $fail -eq 0 ] && echo "PASS" || { echo "--- out"; cat "$W/out"; echo "--- a.jsonl"; cat "$W/a.jsonl"; }
exit $fail
