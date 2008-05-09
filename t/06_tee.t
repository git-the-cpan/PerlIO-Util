#!perl
use strict;
use warnings;
use Test::More tests => 29;

use FindBin qw($Bin);
use File::Spec;

use PerlIO::Util;

ok( PerlIO::Layer->find('tee'), "tee defined" );


ok open(my $tee, ">:scalar :tee", \my($x, $y, $z)), "open";

is_deeply [ $tee->get_layers ], [qw(scalar tee tee)], "2 tees opened";

is fileno($tee), -1, "fileno";
is tell($tee), 0,    "tell == 0";

print $tee "foo";

is $x, "foo", "to x";
is $y, "foo", "to y";
is $z, "foo", "to z";

is tell($tee), length($x), 'tell == length($x)';

ok close($tee), "close";

is_deeply [ map{ Internals::SvREFCNT($_) } $x, $y, $z ], [1, 1, 1], "(refcnt aftere closed)";

open $tee, ">:scalar", \$x;

$tee->push_layer(tee => \$y);
$tee->push_layer(tee => \$z);

is_deeply [ $tee->get_layers ], [qw(scalar tee tee)], "2 tees pushed";

print $tee "bar";

is $x, "bar", "to x";
is $y, "bar", "to y";
is $z, "bar", "to z";


ok close($tee), "close";

is_deeply [ map{ Internals::SvREFCNT($_) } $x, $y, $z ], [1, 1, 1], "(refcnt aftere closed)";

# push filehandle

open $tee, ">", \$x;
open my $o, ">", \$y;

ok $tee->push_layer(tee => $o), "push a filehandle to a filehandle";

print $tee "foo";
is $x, "foo", "to x";
is $y, "foo", "to y";

ok close($tee), "close";

ok defined(fileno($o)), "the pushed filehandle remains opened";


# with open mode
$x = $y = 'x';
open $tee, ">>:scalar :tee", \$x, \$y;
print $tee "y";
print $tee "z";

is $x, "xyz", "append to x";
is $y, "xyz", "append to y";

close $tee;

my $file = File::Spec->catfile($Bin, 'util', '.tee');

ok open($tee, '>:tee', \$x, $file), 'open \$scalar, $file';
ok -e $file, '$file created';

print $tee "foobar";
close $tee;

is $x, "foobar", "to scalar";
is do{ open my $in, '<', $file or die $!; local $/; scalar <$in> },
	"foobar", "to file";

ok unlink($file), "(cleanup)";
