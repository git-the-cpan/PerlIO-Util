#!perl
use strict;
use warnings;
use Test::More tests => 3;


BEGIN{
	use_ok('PerlIO::Util');
}

my %l;
@l{ PerlIO::Util->known_layers() } = ();

ok exists($l{raw}) && exists($l{crlf}), 'known_layers()';

my $crlf = PerlIO::Layer->find('crlf');

is $crlf->name, 'crlf', 'name of PerlIO::Layer';

