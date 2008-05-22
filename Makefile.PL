#!perl

require 5.008_001; # for utf8::is_utf8()

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
