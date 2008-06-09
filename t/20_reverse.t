#!perl
use strict;
use warnings;

use Test::More tests => 29;

use FindBin qw($Bin);
use File::Spec;
use Fatal qw(:void open);

my $f = make_files();
my $r;

ok open($r, '<:reverse', $f->{small}{file}), 'open:reverse (small-sized file)';
is_deeply [<$r>], $f->{small}{contents}, 'readline:reverse';
is scalar(<$r>), undef, 'readline:reverse (EOF)';

ok open($r, '<:reverse', $f->{normal}{file}), 'open:reverse (moderate-sized file)';

is_deeply [<$r>], $f->{normal}{contents}, 'readline:reverse';


ok open($r, '<:reverse', $f->{longline}{file}), 'open:reverse (long-lined file)';
is_deeply [<$r>], $f->{longline}{contents}, 'readline:reverse';
ok close($r), 'close:reverse';

ok open($r, '<:reverse', $f->{nenl}{file}), 'open:reverse (file not ending newline)';
is_deeply [<$r>], $f->{nenl}{contents}, 'readline:reverse';
ok close($r), 'close:reverse';

ok open($r, '<:reverse', $f->{onebyte}{file}), 'open:reverse (one byte file)';
is_deeply [<$r>], $f->{onebyte}{contents}, 'readline:reverse';
ok close($r), 'close:reverse';

ok open($r, '<:reverse', \"foo\nbar\nbaz\n"), 'open:scalar:reverse';
is_deeply [<$r>], ["baz\n", "bar\n", "foo\n"], 'readline:scalar:reverse';
ok close($r), 'close:scalar:reverse';
# Read again

ok open($r, '<', $f->{normal}{file}), 'open:perlio';
is scalar(<$r>), $f->{normal}{contents}[-1], 'normal readline';
#ok binmode $r, ':reverse';
binmode $r;
$r->push_layer('reverse');
is scalar(<$r>), $f->{normal}{contents}[-1], 'backward readline';
$r->pop_layer();
is scalar(<$r>), $f->{normal}{contents}[-1], 'normal readline again';

# Errors

open($r, '<:dir', '.') or die $!;
ok !binmode($r, ':reverse'), "unseekable->push_layer(reverse) failed (\$!=$!)";

SKIP:{
	my $v = sprintf '%vd', $^V;
	skip "perlio.c before perl 5.8.8 (this is $v) has some problems in binmode()", 1
		if $] < 5.008_008;
	1 while $r->pop_layer();
	ok !binmode($r, ':reverse'), ':reverse to invalid filehandle';
}
ok !binmode(STDOUT, ':reverse'), ':reverse to output filehandle';

sub make_files{
	my %f;
	use constant BUFSIZ => 4096;

	my $cts = [];
	my $f1 = File::Spec->catfile($Bin, 'util', 'revlongline');
	open my $o, '>', $f1;
	binmode $o;
	foreach my $s('x' .. 'z'){
		my $c = $s x (BUFSIZ+100) . "\n";
		print $o $c;
		unshift @$cts, $c;
	}
	$f{longline}{file} = $f1;
	$f{longline}{contents} = $cts;

	$cts = [];
	my $f2 = File::Spec->catfile($Bin, 'util', 'revsmall');
	open $o, '>', $f2;
	binmode $o;
	foreach my $s('x' .. 'z'){
		my $c = $s x (10) . "\n";
		print $o $c;
		unshift @$cts, $c;
	}
	$f{small}{file} = $f2;
	$f{small}{contents} = $cts;

	$cts = [];
	my $f3 = File::Spec->catfile($Bin, 'util', 'revnormal');
	open $o, '>', $f3;
	binmode $o;
	foreach my $s(1000 .. 1500){
		my $c = $s . "\n";
		print $o $c;
		unshift @$cts, $c;
	}
	$f{normal}{file} = $f3;
	$f{normal}{contents} = $cts;

	$cts = [];
	my $f4 = File::Spec->catfile($Bin, 'util', 'revnotendnewline');
	open $o, '>', $f4;
	binmode $o;
	print $o "foo\nbar\nbaz";
	@$cts = ("bazbar\n", "foo\n");
	$f{nenl}{file} = $f4;
	$f{nenl}{contents} = $cts;

	$cts = [];
	my $f5 = File::Spec->catfile($Bin, 'util', 'revonebyte');
	open $o, '>', $f5;
	binmode $o;
	print $o "\n";
	@$cts = ("\n");
	$f{onebyte}{file} = $f5;
	$f{onebyte}{contents} = $cts;



	eval q{
		sub END{
			ok unlink($f1), '(cleanup)';
			ok unlink($f2), '(cleanup)';
			ok unlink($f3), '(cleanup)';
			ok unlink($f4), '(cleanup)';
			ok unlink($f5), '(cleanup)';
		}
	};

	return \%f;
}