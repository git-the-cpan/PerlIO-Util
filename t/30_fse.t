#!perl
use strict;
use warnings;
use Test::More;

use PerlIO::Util;
BEGIN{
	if(PerlIO::Util->fse ne 'cp932'){
		plan skip_all => 'PerlIO FSE tests are only for CP932 environment';
		exit;
	}

	plan tests => 10;
}

use FindBin qw($Bin);
use File::Spec;
use utf8;

diag 'fse = ', PerlIO::Util->fse;

my $basename = 'ファイルシステムエンコーディング.txt';
my $utf8 = File::Spec->catfile($Bin, 'util', $basename);
my $fse = PerlIO::Util->fse;

require_ok('PerlIO::fse');

ok open(my $io, '>:fse', $utf8), 'open for writing';

ok(Encode->VERSION, 'Encode.pm loaded');

my $fsnative = Encode::encode(PerlIO::Util->fse, $utf8);

ok -e $fsnative, 'encoded file created';

ok open($io, '<:fse', $utf8), 'open for reading';

ok open($io, "<:fse($fse)", $utf8), 'open for reading (explicit)';

open my $dir, "<:dir:encoding($fse)", File::Spec->join($Bin, 'util');
my($f) = grep { chomp; $_ eq $basename } <$dir>;
is $f, $basename, ":dir:encoding($fse)";
ok open($io, '<:fse', File::Spec->join($Bin, 'util', $f)), '   -> open:fse';
close $io;

eval{
	PerlIO::fse->import('hogehoge');
	open($io, '<:fse', $utf8);
};
ok $@, 'invalid encoding';

ok unlink($fsnative), '(cleanup)';
