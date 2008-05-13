#!perl

use strict;
use warnings;
use Test::More tests => 11;

use FindBin qw($Bin);
use File::Spec;

use PerlIO::Util;

my $file = File::Spec->join($Bin, 'util', '.extra');

unlink $file;

ok open(*IN, '<:creat :excl', $file), "open with :creat and :excl -> success";

is_deeply [STDIN->get_layers], [IN->get_layers], "has correct layers";

close *IN;

ok -e $file, "created";

ok !open(*IN, '<:creat :excl', $file), "open with :creat and :excl -> fail";

unlink $file;

ok open(*IN, '<:excl :creat', $file), "open with :excl and :creat -> success";
close *IN;

ok -e $file, "created";

ok !open(*IN, '<:excl :creat', $file), "open with :excl and :creat -> fail";

unlink $file;


ok open(*IN, '<:utf8 :creat :excl', $file), "open with :utf8, :creat and :excl -> success";
ok -e $file, "created";

ok open(*IN, '<:utf8 :flock :creat', $file), "open with :utf8, :flock and :creat -> success";
close IN;

ok unlink($file), "(cleanup)";
