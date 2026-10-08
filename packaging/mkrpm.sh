#!/bin/sh
#
# packaging/mkrpm.sh - an .rpm of this checkout, for CI and testing
#
#   sh packaging/mkrpm.sh [--srpm] [OUTDIR]
#
# Builds the binary rpm (or, with --srpm, the source rpm for COPR
# submission) from a tarball of the working tree, so uncommitted
# changes are included. Writes into OUTDIR (default: the checkout).
# Needs rpm-build, a C compiler and make.
#
TIGER=${TIGER:-`cd "\`dirname "$0"\`/.." && pwd`}
SRPM=N
case "$1" in --srpm) SRPM=Y; shift;; esac
OUT=${1:-$TIGER}

for t in rpmbuild tar; do
  command -v $t >/dev/null 2>&1 || { echo "mkrpm.sh: $t is needed"; exit 1; }
done
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || { echo "mkrpm.sh: a C compiler is needed"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "mkrpm.sh: make is needed"; exit 1; }
[ -d "$OUT" ] || { echo "mkrpm.sh: $OUT is not a directory"; exit 1; }

TAG=`grep '^%define _tag' "$TIGER/packaging/tigris.spec" | awk '{print $3}'`
[ -n "$TAG" ] || { echo "mkrpm.sh: %define _tag missing from the spec"; exit 1; }
W=`mktemp -d`
trap 'rm -rf "$W"' 0
mkdir -p "$W/rpmbuild/SOURCES" "$W/rpmbuild/SPECS"
cp "$TIGER/packaging/tigris.spec" "$W/rpmbuild/SPECS/"
# SH: transform member names only, never the targets of the tree's links
( cd "$TIGER" && tar --exclude=.git --exclude=./log --exclude=./run \
  --transform "s,^,tigris-$TAG/,SH" -cf - . ) | gzip > "$W/rpmbuild/SOURCES/$TAG.tar.gz"

if [ "$SRPM" = Y ]; then
  rpmbuild -bs --define "_topdir $W/rpmbuild" "$W/rpmbuild/SPECS/tigris.spec" || exit 1
  RPM=`ls "$W"/rpmbuild/SRPMS/*.rpm`
else
  rpmbuild -bb --define "_topdir $W/rpmbuild" "$W/rpmbuild/SPECS/tigris.spec" || exit 1
  RPM=`ls "$W"/rpmbuild/RPMS/*/tigris-[0-9]*.rpm`
fi
[ -f "$RPM" ] || { echo "mkrpm.sh: no package built"; exit 1; }
cp "$RPM" "$OUT/" || exit 1
echo "$OUT/${RPM##*/}"
