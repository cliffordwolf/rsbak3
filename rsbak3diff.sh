#!/bin/bash

if [ ! -d "$1" -o ! -d "$2" ]; then
	echo "Usage: $0 directory1 directory2"
	exit 1
fi

diff -u \
	<( find $1 -type f -printf '%i\t%k\t%P\n' | sort +2 ) \
	<( find $2 -type f -printf '%i\t%k\t%P\n' | sort +2 ) | \
perl -e '
	while (<>) {
		@_ = split /\t/;
		next if /^(---|\+\+\+)/ || $_[2] eq "";
		$a{$_[2]} = $f{$_[2]} = $_[1] if /^\+/;
		$d{$_[2]} = $f{$_[2]} = $_[1] if /^-/;
	}
	$s = 0;
	foreach (sort keys %f) {
		printf("- %9d %s", $d{$_}, $_), $s -= $d{$_} if !defined $a{$_} &&  defined $d{$_};
		printf("+ %9d %s", $a{$_}, $_), $s += $a{$_} if  defined $a{$_} && !defined $d{$_};
		printf("! %9d %s", $a{$_}, $_), $s = $s - $d{$_} + $a{$_} if  defined $a{$_} &&  defined $d{$_};
	}
	print "\nDifference: $s\n";
'

exit 0

