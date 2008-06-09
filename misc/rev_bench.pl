#!perl

use strict;
use warnings;
use Benchmark qw(cmpthese timethese);

use PerlIO::Util;
my $file = @ARGV ? shift(@ARGV) : `perldoc -l perl`;

$file =~ s/\s+$//;

{
	my $in = PerlIO::Util->open('<', $file);
	local $/;
	my $content = <$in>;

	print "file: ", $file, "\n";
	print "line: ", $content =~ tr/\n/\n/, "\n";
	print "size: ", int(length($content) / 1024), " KB\n";
}

cmpthese timethese -1 => {
	':reverse' => sub{
		open my $in, '<:reverse', $file or die $!;
		while(<$in>){
			#...;
		}
	},

	'reverse readline' => sub{
		open my $in, '<', $file or die $!;
		foreach (reverse <$in>){
			# ...
		}
	},
	'readline' => sub{
		open my $in, '<', $file or die $!;
		while(<$in>){
			# ...
		}
	},
};
