#!perl
use strict;
use warnings;

use Test::More tests => 5;

use_ok( 'PerlIO::Util' );

require_ok('PerlIO::flock');
require_ok('PerlIO::creat');
require_ok('PerlIO::excl');
require_ok('PerlIO::tee');

