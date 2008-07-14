#!perl -T
use strict;
use warnings;

use Test::More tests => 5;

use FindBin qw($Bin);
use File::Spec;
use Scalar::Util qw(tainted);

use PerlIO::Util;

# $^X is tainted
my $path = File::Spec->join($Bin, 'util', substr($^X, 0, 0) . 'foo');
ok $path, 'using tainted string';

eval{
	open my $tee, '>:tee', File::Spec->devnull, $path;
};
like $@, qr/insecure/i, 'insecure :tee';

eval{
	*STDERR->push_layer(tee => $path);
};
like $@, qr/insecure/i, 'insecure :tee';

eval{
	open my $io, '+<:creat', $path;
};
like $@, qr/insecure/i, 'insecure :creat';

eval{
	open my $io, '+<:excl', $path;
};
like $@, qr/insecure/i, 'insecure :excl';
