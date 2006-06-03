#!/usr/bin/perl
my $default_dir = "/mnt/backup/rsbak3";
my $dir = $default_dir;

# round up to full 4k blocks
# maybe command line option ???
# or guess fs-blocksize from first directory entry?
sub round_up($) { int(($_[0]+4095)/4096)*4 }

if (@ARGV == 1 and -d $ARGV[0]) {
	$dir = shift;
}

unless (@ARGV) {
	chdir $dir or die "chdir($dir): $!\n";
	@ARGV = map { "$_/" . readlink("$_/latest") . "/rsync.log" } 
		grep { -l "$_/latest" } <*>;
}

unless (@ARGV) {
	print "no '$dir/*/latest/rsync.log' files found, nothing to do\n";
	exit 1;
};

while (<>) {
	# care for directories ?
	($s,$f) = /^.[d]\S+\s+(\d+) (.+)$/ and do {
		$s = round_up $s;
		$s{$ARGV}->{"\0TOTAL"} += $s;
		$s{$ARGV}->{"\0dir_space"} += $s;
		$s{$ARGV}->{"\0directories"} ++;
		next;
	};
	($s,$f) = /^.[f]\S+\s+(\d+) (.+)$/ or next;
	$s = round_up $s;
	$s{$ARGV}->{"\0TOTAL"} += $s;
	$s{$ARGV}->{"\tTOTAL kB file data"} += $s;
	do { $s{$ARGV}->{$f}+=$s; } while $f =~ s:/[^/]*$::;
}

exit 1 unless defined %s;

# I could not decide between dot and comma.
# besides, using underscore has the additional effect
# of not changing the perl numerical value...
#
sub add_1000sep($) {
	my $s = $_[0];
	return $s unless $s =~ /^\d+$/s;
	1 while $s =~ s/(\d)(\d\d\d)(,|$)/${1},$2/;
	# 1 while $s =~ s/(\d)(\d\d\d)(\.|$)/${1}.$2/;
	# 1 while $s =~ s/(\d)(\d\d\d)(_|$)/${1}_$2/;
	return $s;
};

print "\nTOTALs (unit kilo byte)\n";
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	printf "%12s %-20s %s\n",add_1000sep($s{$dir}->{"\0TOTAL"}), split "/",$dir,2;
	if ($s{$dir}->{"\0directories"}) {
		printf "%12s in %d dirs\n\n",
			add_1000sep($s{$dir}->{"\0dir_space"}), $s{$dir}->{"\0directories"};
	} else {
		printf "%12s no directories\n\n", "";
	}
}
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	print "\n$dir\n",
	"=" x 66, "\n";
#	printf "%9d TOTAL\n",$s{$dir}->{"\tTOTAL"};
	$c = 0;
	if (not exists $s{$dir}->{"\tTOTAL kB file data"}) {
		printf "%12s No files transfered -- nothing changed\n", 0;
		next;
	}

	for (sort { $s{$dir}->{$b} <=> $s{$dir}->{$a} or $a cmp $b } keys %{$s{$dir}}) {
		next if /^\0/;
		last if ++$c > 50;
		printf "%12s %s\n", add_1000sep($s{$dir}->{$_}), $_
	};
}

