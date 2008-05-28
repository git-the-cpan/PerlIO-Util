#!perl
use strict;
use warnings;

use Test::More;

use PerlIO::Util;
BEGIN{
	if(!PerlIO::Layer->find('dir')){
		plan skip_all => 'without directory functions';
		exit;
	}
	else{
		plan tests => 42;
	}
}
use IO::Dir;
use FindBin qw($Bin);
use File::Spec;
use IO::Seekable qw(SEEK_SET SEEK_CUR SEEK_END);
use IO::Handle; # ungetc()

ok open(my $dir, '<:dir', '.'), 'open:dir';
is_deeply [$dir->get_layers()], ['dir'], 'only :dir layer';

my @dirs = <$dir>;

is_deeply \@dirs, [ map{ "$_\n" } IO::Dir->new('.')->read() ], '<$dir>';
ok eof($dir), "eof:dir";

seek $dir, 0, 0; # rewind
ok !eof($dir), 'eof:dir after seek:dir (cleared)';

my $first_pos = tell $dir;
ok defined($first_pos), 'tell:dir';

my $first  = <$dir>;
is $first, $dirs[0], 'seek:dir (rewind)';

my $second_pos = tell $dir;
ok defined($second_pos), 'tell:dir';
my $second = <$dir>;

seek $dir, $second_pos, 0;
is scalar(<$dir>), $second, 'seek:dir';

seek $dir, $first_pos, 0;
is scalar(<$dir>), $first, 'seek:dir';

() = <$dir>; # to EOF
my $end_pos = tell $dir;
seek $dir, 0, SEEK_CUR;
is tell($dir), $end_pos, 'SEEK_CUR';
seek $dir, 0, SEEK_SET;
is tell($dir), 0, 'SEEK_SET';
seek $dir, 0, SEEK_END;
is tell($dir), $end_pos, 'SEEK_END';

seek $dir, 0, 0;

is getc($dir), substr($first, 0, 1), 'getc()';
is $dir->ungetc(ord '*'), ord('*'), 'ungetc()';
is getc($dir), '*', 'getc() again';
is getc($dir), substr($first, 1, 1), 'getc()';
is $dir->ungetc(ord '/'), ord('/'), 'ungetc()';
is getc($dir), '/', 'getc() again';

seek $dir, 0, 0;
is $dir->ungetc(ord '?'), ord('?'), 'ungetc()';
is getc($dir), '?', 'getc()';
is getc($dir), substr($first, 0, 1), 'getc()';


ok close($dir), 'close:dir';

open $dir, '<:dir:encoding(CP932)', File::Spec->join($Bin, 'util');

is( (grep{ /^CP932/ } <$dir>)[0],
	# "CP932でエンコードされたファイル"
	"CP932\x{3067}\x{30a8}\x{30f3}\x{30b3}\x{30fc}\x{30c9}\x{3055}\x{308c}\x{305f}\x{30d5}\x{30a1}\x{30a4}\x{30eb}\n",
	':dir with :encoding');

ok close($dir), 'close:dir';

STDIN->push_layer(dir => '.');
is_deeply [ <STDIN> ], \@dirs, 'push_layer:dir';
is(STDIN->pop_layer(), 'dir', 'pop_layer:dir');

ok open($dir, '<:dir:utf8', '.'), 'open:dir';

ok utf8::is_utf8(scalar <$dir>), 'with :utf8';
binmode $dir;
ok !utf8::is_utf8(scalar <$dir>), 'without :utf8';

ok open($dir, '<:dir', '.'), 'open:dir';
ok  seek($dir, $second_pos, SEEK_SET), 'SEEK_SET (OK)';
ok !seek($dir, $second_pos, SEEK_CUR), 'SEEK_CUR (NG)';
ok !seek($dir, $second_pos, SEEK_END), 'SEEK_END (NG)';


$! = 0;
ok !open($dir, '>:dir', '.'), 'open:dir for writing';
ok $!{EPERM}, '... permission denied';
ok !open($dir, '+<:dir', '.'), 'open:dir for update';
ok $!{EPERM}, '... permission denied';

ok !open($dir, '<:dir', File::Spec->join($Bin, 'util', '.lock')), 'open:dir for a file';
ok $!{ENOTDIR}, '... not a directory';

ok !open($dir, '<:dir', File::Spec->join($Bin, 'util', '@@@')), 'open:dir no such directory';
ok $!{ENOENT}, '... no such file or directory';
