#!/bin/bash

# Read from stdin a list of filesystems and
# find if they are present in gen_mounts

SCRIPT=gen_mounts

while read fs ; do
    if ! `grep -q "= \"$fs\"" $SCRIPT` ; then
        echo "ERROR: Filesystem $fs not present in $SCRIPT"
    fi
done
