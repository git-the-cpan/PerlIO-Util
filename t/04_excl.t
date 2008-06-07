#!perl
use strict;
use warnings;
use Test::More tests => 10;

use FindBin qw($Bin);
use File::Spec;
BEGIN{
	eval 'use Fcntl;1' or do{
		*O_RDWR  = sub(){ 0x002 };
		*O_CREAT = sub(){ 0x200 };
	};
}


use Fatal qw(unlink);

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

	ok -e $file, "file exists";
	ok !sysopen(*IN, $file, O_RDWR | O_CREAT), "sysopen with :excl";
	ok $!{EEXIST}, '$! == EEXIST';
}

open IN, $file;

ok !eval{
	no warnings 'layer';
	binmode *IN, ":excl";
} && !$@, "Useless use of :excl";


eval{
	use warnings FATAL => 'layer';
	binmode *IN, ":excl";
};

like $@, qr/Too late/, "Useless use of :excl";

close *IN;


END{
	unlink $file if defined($file) and -e $file;
}