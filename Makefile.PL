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

build_requires 'ExtUtils::ParseXS';

test_requires 'Test::More' => 0.62;

author_tests 'xt';

WriteMakefile(
    OBJECT              => '$(O_FILES)',

    clean               => { FILES =>
    	q{PerlIO-Util-*
    		cover_db
    		*.gcov *.gcda *.gcno
    		*.stackdump
    		*.out
    	} },
);
