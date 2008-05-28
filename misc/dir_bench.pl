#!perl

use strict;
use warnings;
use Benchmark qw(cmpthese timethese);
use File::Basename;

use PerlIO::Util;
my $perlbin = dirname $^X;

my $count = do{
	my $n = 0;
	open my $dir, '<:dir', $perlbin or die $!;
	$n++ while defined(my $d = <$dir>);
	$n;
};
print "read: $count\n";

cmpthese timethese -1 => {
	layer => sub{
		open my $dir, '<:dir', $perlbin or die $!;
		1 while <$dir>;
	},
	core => sub{
		opendir my $dir, $perlbin or die $!;
		1 while defined($_ = readdir $dir);
	},
};
