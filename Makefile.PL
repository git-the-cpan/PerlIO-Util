require 5.008_001; # for PerlIO::get_layers()

use strict;
use warnings;
use inc::Module::Install;

if($] < 5.008_008){
	my $v = sprintf '%vd', $^V;
	warn(<<"END");
**** WARNING ***

Perl version $v is too old to pass all the tests.
Perl version 5.8.8 or later is recommended.

END
	sleep 1;
}

name 'PerlIO-Util';
all_from 'lib/PerlIO/Util.pm';

WriteMakefile(
    OBJECT              => '$(O_FILES)',

    clean               => { FILES => 'PerlIO-Util-* *.gcov *.gcda *.gcno *.stackdump' },
);
