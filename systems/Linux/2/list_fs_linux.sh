#!/bin/bash  -e

# List the filesystems which are valid to the current
# Kernel

# Two sources for filesystem: 
# /proc/filesystems
# /lib/modules/{kernel_name}/kernel/fs

tempfile=`mktemp`
 cat /proc/filesystems | while read type fs; do
    [ -z "$fs" ] && type=$fs
    echo $fs >>$tempfile
done

ls -d /lib/modules/*/kernel/fs/* | while read fsdir; do
    if [ -d "$fsdir" ] ; then
        fs=`basename $fsdir`
        echo $fs >>$tempfile
    fi
done

# Print all the filesystems found
cat $tempfile | sort -u 

rm $tempfile

exit 0 
