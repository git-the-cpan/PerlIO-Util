#!perl

require 5.008_000;

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PerlIO::Util',
    AUTHOR              => 'Goro Fuji <gfuji (at) cpan.org>',
    VERSION_FROM        => 'lib/PerlIO/Util.pm',
    ABSTRACT_FROM       => 'lib/PerlIO/Util.pm',

    LICENSE             => 'perl',

    clean               => { FILES => 'PerlIO-Util-*' },
);
