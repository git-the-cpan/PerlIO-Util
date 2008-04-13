#!perl
use strict;
use warnings;
use Test::More tests => 22;

use FindBin qw($Bin);
use File::Spec;


use PerlIO::Util;
use Fatal qw(unlink);

use subs 'open';
sub open(*;$@){
	my($fh, $layers, @arg) = @_;
	no strict 'refs';
	my $st = CORE::open(*$fh, $layers, @arg);
	if(!$st){
		diag "open failed: $!";
	}
	return $st;
}

ok scalar(PerlIO::Layer->find('creat')), "':creat' is available";

my $file = File::Spec->join($Bin, 'util', '.creat');

ok !-e $file, "before open: the file doesn't exist";

ok open(*IN, "<:creat", $file), "open with :creat";

ok -e $file, "after open: the file does exist";


close *IN;
unlink $file;
ok open(*IN, "<:utf8 :creat", $file), "open with :utf8 :creat";
ok -e $file, "exist";

close *IN;
unlink $file;
ok open(*IN, "<:creat :utf8", $file), "open with :creat :utf8";
ok -e $file, "exist";

close *IN;
unlink $file;
ok open(*IN, "<:raw :creat", $file), "open with :raw :creat";
ok -e $file, "exist";

#close *IN;
#unlink $file;
#ok open(*IN, "<:creat :raw", $file), "open with :creat :raw";
#ok -e $file, "exist";


close *IN;
unlink $file;
ok open(*IN, "<:unix :creat", $file), "open with :unix :creat";
ok -e $file, "exist";
#
#close *IN;
#unlink $file;
#ok open(*IN, "<:creat :unix", $file), "open with :creat :unix";
#ok -e $file, "exist";


close *IN;
unlink $file;
ok open(*IN, "<:crlf :creat", $file), "open with :crlf :creat";
ok -e $file, "exist";

close *IN;
unlink $file;
ok open(*IN, "<:creat :crlf", $file), "open with :creat :crlf";
ok -e $file, "exist";



my @layers = PerlIO::get_layers(*IN);

ok scalar( grep{ $_ eq 'crlf' } @layers ), "has other layers (in [@layers])";

close *IN;
unlink $file;

{
	use open IO => ':creat';
	use Fcntl;

	ok sysopen(*IN, $file, O_RDWR), "sysopen with :creat";

	ok -e $file, "exist";

}


ok eval{
	no warnings 'layer';
	binmode *IN, ":creat";
	$!{EINVAL};
} && !$@, "Useless use of :creat (EINVAL)";

eval{
	use warnings FATAL => 'layer';
	binmode *IN, ":creat";
};

like $@, qr/Too late/, "Useless use of :creat";

ok close(*IN), "close";


END{
	unlink $file if defined($file) and -e $file;
}