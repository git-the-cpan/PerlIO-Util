#!perl

require 5.008_006; # for PerlIO::get_layers()

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PerlIO::Util',
    AUTHOR              => 'Goro Fuji <gfuji (at) cpan.org>',
    VERSION_FROM        => 'lib/PerlIO/Util.pm',
    ABSTRACT_FROM       => 'lib/PerlIO/Util.pm',

    OBJECT              => '$(O_FILES)',

    LICENSE             => 'perl',

    clean               => { FILES => 'PerlIO-Util-* *.gcov *.gcda *.gcno' },
);
