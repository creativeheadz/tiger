#!/bin/sh
#
# packaging/stage.sh - reshape a DESTDIR install into the distro package layout
#
#   sh packaging/stage.sh DESTDIR [LIBDIR]
#
# DESTDIR holds a `make install DESTDIR=...` tree configured --prefix=/usr
# with the tigris paths (--with-tigerhome=$LIBDIR, --with-tigerconfig=
# /etc/tigris, --with-tigerwork=/var/lib/tigris, --with-tigerlog=
# /var/log/tigris, --with-tigerbin=/usr/sbin). LIBDIR defaults to
# /usr/lib/tigris (/usr/lib64/tigris on 64-bit rpm distributions).
#
# The package installs beside Debian's tiger, not over it: only the
# tigris entry points stay in sbin, and only tigris paths are named.
# Every rewrite asserts the text it replaces, so a source change that
# moves it fails the build instead of shipping a broken package.
#
D=${1:?usage: stage.sh DESTDIR [LIBDIR]}
LIB=${2:-/usr/lib/tigris}
case "$LIB" in /*) ;; *) echo "stage.sh: LIBDIR must be absolute"; exit 1;; esac
R=${LIB#/}

fail=0
need() {
  [ -e "$D/$1" ] || { echo "stage.sh: $D/$1 is missing ($2)"; fail=1; }
}
need usr/sbin/tiger "sbin binary"
need usr/sbin/tigris "sbin binary"
need usr/sbin/tigris-diff "sbin binary"
need usr/sbin/tigris-accept "sbin binary"
need usr/sbin/tigexp "sbin binary"
need usr/sbin/tigercron "sbin binary"
need "$R/tigexp" "helper beside the install (HELPERS in Makefile.in)"
need "$R/tigris-diff" "helper beside the install (HELPERS in Makefile.in)"
need etc/tigris/tigerrc "config file"
need etc/tigris/cronrc "config file"
need usr/share/man/man8/tigris.8 "man page"
[ "$fail" -ne 0 ] && exit 1

# sbin keeps the tigris entry points; the rest run from the library dir
mv "$D/usr/sbin/tiger" "$D/usr/sbin/tigexp" "$D/usr/sbin/tigercron" "$D/$R/"

# `tigris explain` looks beside itself for tigexp; bake the library dir
# the way make install bakes the other paths
T=$D/usr/sbin/tigris
grep -q '`dirname "$0"`/tigexp' "$T" || { echo "stage.sh: the explain line moved in tigris"; exit 1; }
sed -i 's#`dirname "$0"`/tigexp#'"$LIB"'/tigexp#' "$T"

# the log and accepted-file defaults name the tigris directories
F=$D/usr/sbin/tigris-diff
grep -q '/var/log/tiger' "$F" || { echo "stage.sh: the log default moved in tigris-diff"; exit 1; }
sed -i 's#/var/log/tiger#/var/log/tigris#' "$F"
A=$D/usr/sbin/tigris-accept
grep -q '/etc/tiger' "$A" || { echo "stage.sh: the accepted-file default moved in tigris-accept"; exit 1; }
sed -i 's#/etc/tiger#/etc/tigris#' "$A"

# man pages: the tigris ones only
rm -f "$D/usr/share/man/man8/tiger.8" "$D/usr/share/man/man8/tigexp.8" "$D/usr/share/man/man8/tigercron.8"

# build droppings stay out of the package
rm -f "$D/$R/doc/Makefile" "$D/$R/doc/Makefile.in"

echo "staged under $D"
