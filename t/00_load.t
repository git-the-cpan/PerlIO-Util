#!perl
use strict;
use warnings;

use Test::More tests => 8;

use_ok( 'PerlIO::Util' );

require_ok('PerlIO::flock');
require_ok('PerlIO::creat');
require_ok('PerlIO::excl');
require_ok('PerlIO::tee');
require_ok('PerlIO::dir');
require_ok('PerlIO::reverse');
require_ok('PerlIO::fse');
