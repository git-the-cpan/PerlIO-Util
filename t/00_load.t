#!perl
use strict;
use warnings;

use Test::More tests => 2;

use_ok( 'PerlIO::Util' );

ok(PerlIO::Util->can('bootstrap'), 'XS loaded');
