#!perl
use strict;
use warnings;
use Test::More tests => 40;

use FindBin qw($Bin);
use File::Spec;
use IO::Handle ();

use PerlIO::Util;

my $file1 = File::Spec->join($Bin, 'util', '.tee1');
my $file2 = File::Spec->join($Bin, 'util', '.tee2');
my($x, $y, $tee);

sub slurp{
	my $file = shift;
	open my $in, '<', $file or die $!;
	local $/;
	binmode $in;
	return scalar <$in>;
}

my $CRLF = "\015\012";

ok open($tee, ">:tee", \($x, $y)), "open:tee scalar, scalar";
ok binmode($tee), "binmode";
print $tee "foo\n";
close $tee;

is $x, "foo\n", "binmode:raw (1) via :scalar";
is $y, "foo\n", "binmode:raw (2) via :scalar";

ok open($tee, ">:tee", \($x, $y)), "open:tee scalar, scalar";

ok binmode($tee, ':crlf'), "binmode(crlf)";
print $tee "foo\n";
close $tee;

is $x, "foo$CRLF", "binmode:crlf (1) via :scalar";
is $y, "foo$CRLF", "binmode:crlf (2) via :scalar";


ok open($tee, '>:tee', $file1, $file2), "open:tee (file, file)";
$tee->autoflush(1);
ok binmode($tee, ':crlf'), 'binmode(crlf)';
print $tee "\n";
is slurp($file1), $CRLF, "binmode:crlf (1)";
is slurp($file2), $CRLF, "binmode:crlf (2)";

#ok open($tee, '>>:tee', $file, $file2), "open";
ok binmode($tee), 'binmode()';
print $tee "\n";
is slurp($file1), "$CRLF\n", "binmode:raw (1)";
is slurp($file2), "$CRLF\n", "binmode:raw (2)";

ok open($tee, '>:tee', \$x, $file1), "open:tee scalar, file";
$tee->autoflush(1);

ok binmode($tee), 'binmode()';
print $tee "foobar", "\n";
is slurp($file1), "foobar\n", "binmode:raw (1)";
is $x,            "foobar\n", "binmode:raw (2)";

ok binmode($tee, ':crlf'), 'binmode(crlf)';
print $tee "\n";
is slurp($file1), "foobar\n$CRLF", "binmode:crlf (1)";
is $x,            "foobar\n$CRLF", "binmode:crlf (2)";

ok binmode($tee), 'binmode()';
print $tee "\n";
is slurp($file1), "foobar\n$CRLF\n", "binmode:raw (1)";
is $x,            "foobar\n$CRLF\n", "binmode:raw (2)";

close $tee;

ok open($tee, '>:tee', $file1, \$x), "open:tee file, scalar";
$tee->autoflush(1);

ok binmode($tee), 'binmode()';
print $tee "foobar", "\n";
is slurp($file1), "foobar\n", "binmode:raw (1)";
is $x,            "foobar\n", "binmode:raw (2)";

ok binmode($tee, ':crlf'), 'binmode(crlf)';
print $tee "\n";
is slurp($file1), "foobar\n$CRLF", "binmode:crlf (1)";
is $x,            "foobar\n$CRLF", "binmode:crlf (2)";

ok binmode($tee), 'binmode()';
print $tee "\n";
is slurp($file1), "foobar\n$CRLF\n", "binmode:raw (1)";
is $x,            "foobar\n$CRLF\n", "binmode:raw (2)";

close $tee;


# binmode clears UTF8 mode
open $tee, '>:tee :utf8', \($x, $y);

ok scalar(grep{ $_ eq 'utf8' } $tee->get_layers()), ':tee with :utf8';
ok binmode($tee), 'binmode()';
ok!scalar(grep{ $_ eq 'utf8' } $tee->get_layers()), 'binmode:raw';

close $tee;


ok unlink($file1), "unlink $file1";
ok unlink($file2), "unlink $file2";
