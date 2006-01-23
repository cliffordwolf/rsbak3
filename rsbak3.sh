#!/bin/bash
#
# RSBAK3 is Copyright (C) 2003, 2004 LINBIT <http://www.linbit.com/>.
#
# Written by Clifford Wolf <clifford@clifford.at>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at COPYING.

ver=0.2
exec 2>&1

verbose=0
if [ "$1" = "-v" ]; then
	verbose=1; shift
fi
if [ -n "$RSBAK3_VERBOSE" ]; then
	verbose=$RSBAK3_VERBOSE
fi

errlog() {
	logger -p user.crit -t "rsbak3" "$*"
}

if [ $verbose = 1 -o -z "$1" -o ! -f "$1" ]; then
	vecho() { echo "$@"; }
else
	vecho() { :; }
fi

if [ -z "$DONT_SHOW_RSBAK3_COPY" ]; then
  vecho
  vecho "RSBAK3 $ver is Copyright (C) 2003 LINBIT <http://www.linbit.com/>."
  vecho "Written by Clifford Wolf <clifford@clifford.at>."
  vecho "This is free software with ABSOLUTELY NO WARRANTY."
  vecho
fi

export DONT_SHOW_RSBAK3_COPY=1
export RSBAK3_VERBOSE=$verbose

if [ -z "$1" -o ! -f "$1" ]; then
	echo "Usage: $0 [-v] config-file [ config-name ]"
	echo; exit 1
fi

if [ ! -z "$3" ]; then
	rc=0; f="$1"; shift
	for cfg; do
		"$0" "$f" "$cfg" || rc=1
	done
	exit $rc
fi

if [ "${2/\\*/}" != "$2" ]; then
	rc=0; found=0
	for cfg in $( grep '^\[' "$1" | tr -d '[]' | grep -v '\*' ); do
		if [[ "$cfg" == $2 ]]; then
			"$0" "$1" "$cfg" || rc=1
			found=1
		fi
	done
	if [ $found -eq 0 ]; then
		echo "$2:$this: Can't find configs matching >>$2<< in config file $1!"
		echo; exit 1
	fi
	exit $rc
fi

if [ -z "$2" ]; then
	rc=0
	for cfg in $( grep '^\[' "$1" | tr -d '[]' | grep -v '\*' ); do
		"$0" "$1" "$cfg" || rc=1
	done
	exit $rc
fi

master=""
backupdir=""
generations=""
rsopt=""
current=""
foundcfg=0

this=$( date '+%Y%m%d-%H%M%S' )
vecho "[ $2:$this ]"

# it's easier to use that var than escaping the character...
t="'"

while read tag value
do
	[ "$tag" != "${tag#\#}" ] && continue
	
	if [ "$tag" = "[" ]; then
		current="${value%% *}"
		continue
	fi

	[[ "$2" == $current ]] || continue
	[ "$2" == "$current" ] && foundcfg=1

	case "$tag" in
	    master)
		master="$value"
		;;
	    backup-dir)
		backupdir="$value"
		;;
	    generations)
		generations="$value"
		;;
	    password)
		export RSYNC_PASSWORD="$value"
		;;
	    password-file|exclude|include|bwlimit)
		rsopt="$rsopt --$tag='${value//$t/$t\\$t$t}'"
		;;
	    exclude-from|include-from)
		rsopt="$rsopt --$tag='${value//$t/$t\\$t$t}'"
		;;
	    include-tree)
	    	x=""; while read y; do
			x="$x/$y"
			rsopt="$rsopt --include='${x//$t/$t\\$t$t}'"
		done < <( echo "$value" | tr '/' '\n' | grep . )
		;;
	    cvs-exclude|compress|whole-file)
		rsopt="$rsopt --$tag"
		;;
	    rsh-command)
		rsopt="$rsopt --rsh='${value//$t/$t\\$t$t}'"
		;;
	    system-exclude)
		rsopt="$rsopt --exclude='/tmp/**'"
		rsopt="$rsopt --exclude='/dev/**'"
		rsopt="$rsopt --exclude='.journal'"
		rsopt="$rsopt --exclude='lost+found/'"
		rsopt="$rsopt --exclude='/proc/**'"
		rsopt="$rsopt --exclude='/sys/**'"
		;;
	    rsync-option)
		rsopt="$rsopt $value"
		;;
	    '')
		;;
	    *)
		echo "$2:$this: Syntax error in config file: $tag $value!"
		echo; exit 1
		;;
	esac
done < "$1"

if [ $foundcfg = 0 ]; then
	echo "$2:$this: Can't find config >>$2<< in config file $1!"
	echo; exit 1
fi

if [ -z "$master" ]; then
	echo "$2:$this: No >>master<< entry in config file!"
	echo; exit 1
fi

if [ -z "$backupdir" ]; then
	echo "$2:$this: No >>backup-dir<< entry in config file!"
	echo; exit 1
fi

if [ -z "$generations" ]; then
	echo "$2:$this: No >>generations<< entry in config file!"
	echo; exit 1
fi

if ! cd "$backupdir" ||
   ! mkdir -p "$2/generation_0" ||
   ! cd "$2/generation_0"
then
	echo "$2:$this: Error while creating $backupdir/$2/generation_0"
	errlog "$2:$this: Error while creating $backupdir/$2/generation_0"
	echo; exit 1
fi

set -C
if ! echo "Already running with PID $$ [$0 $*]." > LOCKFILE
then
	echo "Found lockfile $PWD/LOCKFILE:"
	errlog "Found lockfile $PWD/LOCKFILE"
	cat LOCKFILE; echo; exit 1
fi
set +C
trap "rm -f $PWD/LOCKFILE" EXIT

last=$( ls -d [0-9]*.bak 2> /dev/null | tail -1 )

rm -rf "$this.new"
rsopt="$rsopt -O '--log-format=%i %9l %n%L'"
if [ -d "$last" ]; then
	vecho "Preparing incremental backup using ${last%.bak} ..."
	rsopt="$rsopt '--link-dest=$PWD/$last/'"
fi

vecho "Running rsync (output redirected to logfile) ..."

# vecho "rsync '$master' '$this.new' --archive -v --stats" \
#       "--delete-excluded --ignore-errors --delete $rsopt"

eval 'rsync "$master" "$this.new" --archive -v --stats' \
	'--delete-excluded --ignore-errors --delete' \
	"$rsopt" > $this.log 2> $this.err < /dev/null
rsync_rc=$?

# ignore error 24 = Partial transfer due to vanished source files
if [ $rsync_rc != 0 -a $rsync_rc != 24 ]
then
	echo "$2:$this: rsync returned an error, see $this.log and $this.err:"
	errlog "$2:$this: rsync returned an error, see $this.log and $this.err."
	echo; tail "$this.log" "$this.err"; echo; exit 1
fi

if [ $verbose = 1 ]; then
	tail -n2 "$this.log" | tr -s ' '
fi

mv "$this.log" "$this.new/rsync.log"
mv "$this.err" "$this.new/rsync.err"
mv "$this.new" "$this.bak"

rm -f ../latest
ln -s "generation_0/$this.bak" ../latest

c=0
for gen in $generations; do
	eval "gen_${c}_num=${gen%:*}"
	eval "gen_${c}_rot=${gen#*:}"
	(( c++ ))
done

for gen in 0 1 2 3 4 5 6 7 8 9; do
	[ -d ../generation_$gen ] || break
	cd ../generation_$gen

	eval "num=\$gen_${gen}_num"
	eval "rot=\$gen_${gen}_rot"
	(( next = gen + 1 ))

	if eval "[ -z \"\$gen_${next}_num\" ]"
	then last=1; else last=0; fi

	gencount="$( [ -s GENCOUNT ] && egrep '^[0-9]+$' GENCOUNT | head -1 )"
	[ -z "$gencount" ] && gencount=$rot

	for dir in $( ls -r -d [0-9]*.bak 2> /dev/null | tail +$(($num+1)) )
	do
		(( gencount = $gencount + 1 ))
		if [ $gencount -ge $rot -a $last -eq 0 ]; then
			vecho "Moving to next generation: [$gen] ${dir%.bak} ..."
			mkdir -p ../generation_$next
			mv $dir ../generation_$next/
			gencount=0
		else
			vecho "Removing outdated backup: [$gen] ${dir%.bak} ..."
			rm -rf $dir
		fi
	done

	echo $gencount > GENCOUNT
done

vecho

