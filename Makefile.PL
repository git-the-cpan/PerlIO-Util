require 5.008_001; # for PerlIO::get_layers()

use strict;
use warnings;
use ExtUtils::MakeMaker;

if($] < 5.008_008){
	my $v = sprintf '%vd', $^V;
	warn(<<"END");
**** WARNING ***

Perl version $v is too old to pass all the tests.
Perl version 5.8.8 or later is recommended.

END
	sleep 1;
}

WriteMakefile(
    NAME                => 'PerlIO::Util',
    AUTHOR              => 'Goro Fuji <gfuji(at)cpan.org>',
    VERSION_FROM        => 'lib/PerlIO/Util.pm',
    ABSTRACT_FROM       => 'lib/PerlIO/Util.pm',

    OBJECT              => '$(O_FILES)',

    LICENSE             => 'perl',

    clean               => { FILES => 'PerlIO-Util-* *.gcov *.gcda *.gcno' },
);
