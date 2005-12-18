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

print "\nTOTALs (unit kilo byte)\n";
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	printf "%9d %-20s %s\n",$s{$dir}->{"\0TOTAL"}, split "/",$dir,2;
	printf "%9d in %d dirs\n\n",
		$s{$dir}->{"\0dir_space"}, $s{$dir}->{"\0directories"};
}
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	print "\n$dir\n",
	"=" x 66, "\n";
#	printf "%9d TOTAL\n",$s{$dir}->{"\tTOTAL"};
	$c = 0;
	if (not exists $s{$dir}->{"\tTOTAL kB file data"}) {
		printf "%9d No files transfered -- nothing changed\n", 0;
		next;
	}

	for (sort { $s{$dir}->{$b} <=> $s{$dir}->{$a} or $a cmp $b } keys %{$s{$dir}}) {
		next if /^\0/;
		last if ++$c > 50;
		printf "%9d %s\n", $s{$dir}->{$_}, $_
	};
}

