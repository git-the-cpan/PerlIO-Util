#!perl
use strict;
use warnings;
use Test::More tests => 18;

use FindBin qw($Bin);
use File::Spec;

BEGIN{
	eval 'use Fcntl;1'
		or *O_RDONLY = sub(){ 0 }; # maybe
}

use PerlIO::Util;

ok scalar(PerlIO::Layer->find('flock')), "':flock' is available";


my $file = File::Spec->catfile($Bin, "util/.lock");

my $helper = File::Spec->catfile($Bin, "util/locktest.pl");

ok open(IN, "<:flock", $file), "open with :flock";
ok close(IN), "close";

{
	local $@ = '';
	eval{
		open IN, "<:flock(blocking)", $file or die;
	};
	is $@, '', ":flock(blocking) - OK";

	eval{
		open IN, "<:flock(non-blocking)", $file or die;
	};
	is $@, '', ":flock(non-blocking) - OK";

	eval{
		open IN, "<:flock(foo)", $file or die;
	};
	isnt $@, '', ":flock(foo) - FATAL";

}

{
	no warnings 'io';
	select select my $unopened;
	
	ok !defined(binmode $unopened, ':flock'), ":flock to unopened filehandle (binmode)";
	ok !eval{ $unopened->push_layer('flock');1 }, ":flock to unopened filehandle (push_layer)";
}
ok open(IN, "<:flock", $file), "open(readonly) in this process";
ok system($^X, "-Mblib", $helper, "<:flock", $file),
	"open(readonly) in child process";

is scalar(<IN>), "OK", "readline";

isnt system($^X, "-Mblib", $helper, "+<:flock(non-blocking)", $file), 0,
	"open(rdwr) in child process -> failed";


open IN, "<", $file;

ok binmode(IN, ":flock"), "binmode IN, ':flock'";
ok system($^X, "-Mblib", $helper, "<:flock", $file),
	"open(readonly) in child process";
isnt system($^X, "-Mblib", $helper, "+<:flock(non-blocking)", $file), 0,
	"open(rdwr) in child process -> failed";

{
	use open IO => ':flock';

	ok sysopen(IN, $file, O_RDONLY), "sysopen with :flock";
	ok system($^X, "-Mblib", $helper, "<:flock", $file),
		"shared lock in child process";
	isnt system($^X, "-Mblib", $helper, "+<:flock(non-blocking)", $file), 0,
		"exclusive lock in child process";
	close IN;
}

