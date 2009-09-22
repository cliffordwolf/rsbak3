#!/usr/bin/perl
my $default_dir = "/mnt/backup/rsbak3";
my $dir = $default_dir;

my $cutoff = 50;
my ($inode_dize, $dir_size, $block_size) = (4096, 4096, 4096);

# round up to full blocks
sub round_up_dir($) {
	$_[0] > $inode_size
	? int(($_[0]+$dir_size-1)/$dir_size)*$dir_size
	: int(($_[0]+$inode_size-1)/$inode_size)*$inode_size
}
sub round_up_file($) {
	int(($_[0]+$block_size-1)/$block_size)*$block_size
}

# use getopt or similar?
for (@ARGV) {
	/^--cut=(\d+)$/ and do {
		$cutoff = $1;
		shift;
		}, next;
	/^--bsz=(\d+)$/ and do {
		$inode_size = $dir_size = $block_size = $1;
		shift;
		}, next;
	/^--dsz=(\d+)$/ and do {
		$dir_size = $1;
		shift;
		}, next;
	/^--isz=(\d+)$/ and do {
		$inode_size = $1;
		shift;
		}, next;
	last;
}

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
	close ARGV if eof ARGV;
	# care for directories ?
	($s,$f) = /^.[d]\S+\s+(\d+) (.+)$/ and do {
		$s = round_up_dir $s;
		$s{$ARGV}->{"\0TOTAL"} += $s;
		$s{$ARGV}->{"\0dir_space"} += $s;
		$s{$ARGV}->{"\0directories"} ++;
		next;
	};
	/^TOTAL TIME: (\d+) s/ and do {
		# if ARGV happens to be -, it may occur several times
		$s{$ARGV}->{"\0TOTAL TIME"} += $1; 
		next;
	};
	($s,$f) = /^.[f]\S+\s+(\d+) (.+)$/ or next;
	$s = round_up_file $s;
	$s{$ARGV}->{"\0TOTAL"} += $s;
	$s{$ARGV}->{"\tTOTAL file data"} += $s;
	$s{$ARGV}->{$f} = $s;
	while ($f =~ s:/[^/]*$::) { $s{$ARGV}->{"$f/"} += $s; }
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
sub pretty_size($) { return add_1000sep(round_up_file($_[0])/1024) }

printf "\n%12s %-20s %8s\n", "TOTALs   KiB", "", "HH:MM:SS";
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	my $t = $s{$dir}->{"\0TOTAL TIME"};
	my $pretty_time =
		defined $t ?
			$t >= 3600 ? sprintf "%u:%02u:%02u", ($t / 3600), (($t % 3600) / 60), ($t % 60) :
			$t >=   60 ? sprintf "%u:%02u", $t / 60, $t % 60 :
				     sprintf "%u", $t :
		"";
	my ($base, $tail) = split "/",$dir,2;
	printf "%12s %-20s %8s %s\n",
		pretty_size($s{$dir}->{"\0TOTAL"}),
		$base, $pretty_time, $tail;
	if ($s{$dir}->{"\0directories"}) {
		printf "%12s in %d dirs\n\n",
			pretty_size($s{$dir}->{"\0dir_space"}), $s{$dir}->{"\0directories"};
	} else {
		printf "%12s no directories\n\n", "";
	}
}
for $dir (sort { $s{$b}->{"\0TOTAL"} <=> $s{$a}->{"\0TOTAL"} } keys %s) {
	print "\n$dir\n",
	"=" x 66, "\n";
#	printf "%9d TOTAL\n",$s{$dir}->{"\tTOTAL"};
	$c = 0;
	if (not exists $s{$dir}->{"\tTOTAL file data"}) {
		printf "%12s No files transfered -- nothing changed\n", 0;
		next;
	}

	for (sort { $s{$dir}->{$b} <=> $s{$dir}->{$a} or $a cmp $b } keys %{$s{$dir}}) {
		next if /^\0/;
		last if ++$c > $cutoff;
		printf "%12s %s\n", pretty_size($s{$dir}->{$_}), $_
	};
}

