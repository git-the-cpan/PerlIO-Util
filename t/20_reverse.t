#!perl
use strict;
use warnings;

use Test::More tests => 20;

use FindBin qw($Bin);
use File::Spec;
use Fatal qw(open);

use PerlIO::reverse;
use PerlIO::Util;

ok(PerlIO::Layer->find('reverse'), ':reverse exists');

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


ok open($r, '<', $f->{normal}{file}), 'open:perlio';
is scalar(<$r>), $f->{normal}{contents}[-1], 'normal readline';
$r->push_layer('reverse');
is scalar(<$r>), $f->{normal}{contents}[-1], 'backward readline';
$r->pop_layer();
is scalar(<$r>), $f->{normal}{contents}[-1], 'normal readline again';



sub make_files{
	use POSIX qw(BUFSIZ);
	my %f;

	my $cts = [];
	my $f1 = File::Spec->catfile($Bin, 'util', 'revlongline');
	open my $o, '>', $f1;
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
	print $o "foo\nbar";
	@$cts = ("bar\n", "foo");
	$f{nenl}{file} = $f4;
	$f{nenl}{contents} = $cts;

	eval q{
		END{
			ok unlink($f1), '(cleanup)';
			ok unlink($f2), '(cleanup)';
			ok unlink($f3), '(cleanup)';
			ok unlink($f4), '(cleanup)';
		}
	};

	return \%f;
}