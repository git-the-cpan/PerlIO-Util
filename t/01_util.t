#!perl
use strict;
use warnings;
use Test::More tests => 14;

use IO::Handle;

BEGIN{
	use_ok('PerlIO::Util');
}

sub anonio(){
	return select select my $anonio;
}

my %l;
my @layers = PerlIO::Util->known_layers();

@l{ @layers } = ();

ok scalar(@layers), 'known_layers()';
ok exists $l{raw},  ':raw exists';
ok exists $l{crlf}, ':crlf exists';


# IO::Handle::push_layer()/pop_layer()
my $s = 'bar';
@layers = DATA->get_layers();

DATA->push_layer(scalar => \$s);

is_deeply [DATA->get_layers()], [@layers, 'scalar'], 'push_layer(scalar)';

is scalar(<DATA>), 'bar', '... pushed correctly';

DATA->pop_layer();

is_deeply [DATA->get_layers()], \@layers, 'pop_layer()';
is scalar(<DATA>), "foo\n", '... popped correctly';


DATA->push_layer(':utf8');
is_deeply [DATA->get_layers()], [@layers, 'utf8'], 'allows ":foo" style';
DATA->pop_layer();

is *DATA->push_layer('crlf')->fileno(), fileno(*DATA),
	'push_layer() returns self';

is *DATA->pop_layer(), 'crlf', 'pop_layer() returns the name of the poped layer';

eval{
	local $INC{'PerlIO/foo.pm'} = __FILE__;

	DATA->push_layer('foo');
};

like $@, qr/Unknown PerlIO layer/, 'push_layer(): Unknown PerlIO layer';

eval{
	anonio()->push_layer('raw');
};

like $@, qr/Invalid filehandle/, 'push_layer(): Invalid filehandle';

eval{
	anonio()->pop_layer();
};

like $@, qr/Invalid filehandle/, 'pop_layer(): Invalid filehandle';


__DATA__
foo
