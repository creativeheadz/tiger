#!/bin/sh
#
# tests/hostinfo_check.sh - gethostinfo against uname stubs
#
# FreeBSD, OpenBSD and NetBSD must resolve to their kernel names
# (nothing else in the tree knows them yet); Linux keeps its
# shortcut and Darwin keeps MacOSX, so the override changes
# nothing for them. gethostinfo needs a WORKDIR for its probe
# file. Same output as a user and as root.
#
TIGER=${TIGER:-`cd "\`dirname \"$0\"\`/.." && pwd`}
W=`mktemp -d`
trap 'rm -rf "$W"' 0
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
probe() {  # probe STUB: gethostinfo with the uname stub
  ( Tiger_Uname_Cmd="$TIGER/tests/fixtures/uname/$1" WORKDIR=$W sh "$TIGER/util/gethostinfo" ) 2>/dev/null
}

[ "`probe freebsd`" = "FreeBSD 14.1-RELEASE amd64" ] &&
  ok "FreeBSD resolves" || bad "freebsd: `probe freebsd`"
[ "`probe openbsd`" = "OpenBSD 7.4 amd64" ] &&
  ok "OpenBSD resolves" || bad "openbsd: `probe openbsd`"
[ "`probe netbsd`" = "NetBSD 10.0 amd64" ] &&
  ok "NetBSD resolves" || bad "netbsd: `probe netbsd`"
case "`probe darwin`" in
  'MacOSX 23.1.0 '*) ok "Darwin still MacOSX" ;;
  *) bad "darwin: `probe darwin`" ;;
esac
case "`probe linux`" in
  'Linux 6.8.0 x86_64') ok "Linux shortcut unchanged" ;;
  *) bad "linux: `probe linux`" ;;
esac

[ $fail -eq 0 ] && echo "PASS"
exit $fail
