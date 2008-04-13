#!perl
use strict;
use warnings;
use Test::More tests => 4;


BEGIN{
	use_ok('PerlIO::Util');
}

my %l;
my @layers = PerlIO::Util->known_layers();

@l{ @layers } = ();

ok scalar(@layers), 'known_layers()';
ok exists $l{raw},  ':raw exists';
ok exists $l{crlf}, ':crlf exists';
