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
		chomp; @_ = split /\t/;
		next if /^(---|\+\+\+)/ || $_[2] eq "";
		$a{$_[2]} = $f{$_[2]} = $_[1] if /^\+/;
		$d{$_[2]} = $f{$_[2]} = $_[1] if /^-/;
	}
	$s = 0;
	foreach (sort keys %f) {
		if ( !defined $a{$_} && defined $d{$_} ) {
			printf("- %9d %s\n", $d{$_}, $_);
			$s -= $d{$_};
		}
		if ( defined $a{$_} && !defined $d{$_} ) {
			printf("+ %9d %s\n", $a{$_}, $_);
			$s += $a{$_};
		}
		if ( defined $a{$_} && defined $d{$_} ) {
			printf("! %9d %s\n", $a{$_}, $_);
			$s = $s - $d{$_} + $a{$_};
		}
		$x = $_;
		while ( $x ne "" ) {
			$s{$x} = defined $s{$x} ? $s{$x} + $f{$_} : $f{$_};
			$x =~ s/\/?[^\/]*$//;
		}
	}
	print "\n";
	foreach (keys %s) {
		$u{sprintf "%011d %s", 100000000 - $s{$_}, $_} =
			sprintf("* %9s %s", $s{$_}, $_);
	}
	$c=50;
	foreach (sort keys %u) {
		last if $c-- <= 0;
		print "$u{$_}\n";
	}
	print "\nDifference: $s\n";
'

exit 0

