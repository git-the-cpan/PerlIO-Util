#!perl
use strict;
use warnings;
use Test::More tests => 10;

use FindBin qw($Bin);
use File::Spec;


use PerlIO::Util;
use Fatal qw(unlink);

ok scalar(PerlIO::Layer->find('excl')), "':excl' is available";

my $file = File::Spec->join($Bin, 'util', '.excl');

ok !-e $file, "before open: the file doesn't exist";

ok open(*IN, ">:excl", $file), "open with :excl";

ok -e $file, "after open: the file does exist";

close *IN;

ok !open(*IN, ">:excl", $file), "open an existing file with :excl: failed(File exists)";

ok $!{EEXIST}, '$! == EEXIST';

close *IN;

{
	local $!;
	use open IO => ':excl';
	use Fcntl;

	ok -e $file, "file exists";
	ok !sysopen(*IN, $file, O_RDWR | O_CREAT), "sysopen with :excl";
	ok $!{EEXIST}, '$! == EEXIST';
}

open IN, $file;

eval{
	binmode *IN, ":excl";
};

like $@, qr/Useless/, "Useless use of :excl";

close *IN;


END{
	unlink $file if defined($file) and -e $file;
}