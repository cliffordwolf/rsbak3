#!/bin/bash
#
# RSBAK3 is Copyright (C) 2003 LINBIT <http://www.linbit.com/>.
#
# Written by Clifford Wolf <clifford@clifford.at>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at COPYING.

if [ "$#" != "3" -o ! -d "$2" ]; then
	echo
	echo "rsbak3 helper for dumping databases so they can be backed up."
	echo
	echo "Usage: $0 'dump-command' 'backup-dir' 'max-hist'"
	echo
	exit 1
fi

tm=$( date +'%Y%m%d-%H%M%S' )
echo "Dumping new tuple $tm ..."
mkdir -p "$2.tmp"
eval "$1" | gzip --rsyncable > "$2.tmp/dump.gz"
echo "$tm" > "$2.tmp/dump.tm"

deltarot=0
[ -f $2/dump.gz -a $3 -gt 0 ] && deltarot=1

if [ $deltarot = 1 ]; then
	echo "Creating bi-directional deltas ..."
	xdelta delta -p "$2.tmp/dump.gz" "$2/dump.gz" "$2.tmp/$tm.bw_delta"
	xdelta delta -p "$2/dump.gz" "$2.tmp/dump.gz" "$2.tmp/$tm.fw_delta"
fi

echo "Putting new dump in place ..."
if [ $deltarot = 1 ]; then
	mv -fv "$2.tmp/$tm.bw_delta" "$2/"
	mv -fv "$2.tmp/$tm.fw_delta" "$2/"
fi
mv -fv "$2.tmp/dump.gz" "$2/"
mv -fv "$2.tmp/dump.tm" "$2/"
rm -rf "$2.tmp"

if [ $deltarot = 1 ]; then
	echo "Removing old deltas ..."
	ls -r "$2/"[0-9]*.bw_delta | tail -n +$(( $3 + 1 )) | xargs -r rm -vf
	ls -r "$2/"[0-9]*.fw_delta | tail -n +$(( $3 + 1 )) | xargs -r rm -vf
fi

