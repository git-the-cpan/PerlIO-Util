package PerlIO::Util;

use strict;

our $VERSION = '0.20';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

*IO::Handle::get_layers = \&PerlIO::get_layers;

sub open{
	unless(@_ >= 3){
		require Carp;
		Carp::croak('Usage: PerlIO::Util->open($mode, @args)');
	}
	my $anonio;
	unless(CORE::open $anonio, $_[1], @_[2 .. $#_]){
		require Carp;
		local $" = ', ';
		Carp::croak("Cannot open(@_): $!");
	}
	return bless $anonio => 'IO::Handle';
}

1;
__END__

=encoding utf-8

=head1 NAME

PerlIO::Util - A selection of general PerlIO utilities

=head1 VERSION

This document describes PerlIO::Util version 0.20

=head1 SYNOPSIS

    use PerlIO::Util;

    # utility layers

    open IN, "+<:flock", ...; # with flock(IN, LOCK_EX)

    open IN, "+<:creat :excl", ...; # with O_CREAT | O_EXCL

    open OUT, ">:tee", $file, @others;
    print OUT "foo"; # print to $file and @others

    # utility routines

    STDOUT->push_layer(scalar => \my $s);
    print "foo";

    print STDOUT->pop_layer(); # => scalar

    print $s; # => foo

=head1 DESCRIPTION

C<PerlIO::Util> provides general PerlIO utilities: utility layers and utility
methods.

Utility layers are a part of C<PerlIO::Util>, but you don't need to
say C<use PerlIO::Util> for loading them. They are automatically loaded.

=head1 UTILITY LAYERS

=head2 :flock

The C<:flock> layer provides an interface to C<flock()>.

It tries to lock the filehandle in C<open()> (or C<binmode()>) with
C<flock()> according to the open mode. That is, if a file is opened for writing,
C<:flock> attempts exclusive lock (using LOCK_EX). Otherwise, it attempts
shared lock (using LOCK_SH).

It waits until the lock is granted. If an argument C<non-blocking> (or
C<LOCK_NB>) is suplied, the call of C<open()> fails when the lock cannot be
granted.

For example:

	# tries shared lock, or waits until the lock is granted
	open IN, "<:flock", $file;
	open IN, "<:flock(blocking)", $file;     # ditto.

	# tries shared lock, or returns undef
	open IN, "<:flock(non-blocking)", $file; 
	open IN, "<:flock(LOCK_NB)", $file;      # ditto.

See L<perlfunc/flock>.

=head2 :creat

=head2 :excl

They append O_CREAT or O_EXCL to the open flags.

When you'd like to create a file but not to truncate it, then you can use 
the C<:creat> layer with the open mode '<' or '+<'.

	open(IO, '+< :creat', $file);

When you'd like to create a file only if it doesn't exist before, then you
can use the C<:excl> layer with the C<:creat> layer and '<' or '+<'.

	open(IO, '+< :excl :creat', $file);

That is, it is used to emulate a part of C<sysopen()> without C<Fcntl>.

See L<perlfunc/sysopen>.

=head2 :tee

The C<:tee> layer provides a multiplex output stream like C<tee(1)> command.
It is used to make a filehandle write to one or more files (or
scalars via the C<:scalar> layer) at the same time.

You can use C<push_layer()> (defined in C<PerlIO::Util>) to add a I<source>
to a filehandle. The I<source> may be a file name, a scalar reference, or a
filehandle. For example:

	$fh->push_layer(tee => $file);    # meaning "> $file"
	$fh->push_layer(tee => ">>$file");# append mode
	$fh->push_layer(tee => \$scalar); # via :scalar
	$fh->push_layer(tee => \*OUT);    # shallow copy, not duplication

You can also use C<open()> with multiple arguments.
However, it is just a syntax sugar to call C<push_layer()>: One C<:tee>
layer has a single extra filehandle, so arguments C<$x, $y, $z> of C<open()>,
for example, prepares a filehandle with one basic layer and two C<:tee>
layers with a internal filehandle.

	open my $tee, '>:tee', $x, $y, $z;
	# the code above means:
	#   open my $tee, '>', $x;
	#   $tee->push_layer(tee => $y);
	#   $tee->push_layer(tee => $z);

	$tee->get_layers(); # => "perlio", "tee($y)", "tee($z)"

	$tee->pop_layer();  # "tee($z)" is popped
	$tee->pop_layer();  # "tee($y)" is popped
	# now $tee is a filehandle only to $x

=head1 :dir

The C<:dir> layer provides an interface to directories.

There is an important difference from Perl's C<readdir()>. This layer
B<appends a newline code>, C<\n>, to the end of the name, because
C<readline()> requires input separators. Call C<chomp()> if necesary.

	open my $dir, '<:dir', '.';
	my @dirs = <$dir>;    # readdir() but added "\n" at the end of the name
	chomp @dirs;          # if necessary

You can call C<tell()> and C<seek()>, although there are some limits.
C<seek()> refuses SEEK_CUR and SEEK_END with a non-zero potition value.
And C<tell()> returns an integer that refuses any arithmetic operations.

	my $pos = tell($dir); # telldir()
	seek $dir, $pos, 0;   # seekdir()
	seek $dir, 0, 0;      # rewinddir()

	close $dir;           # closedir()

=head1 UTILITY METHODS

=head2 PerlIO::Util-E<gt>open($mode, @args)

Calls built-in C<open()>, and returns an anonymus C<IO::Handle> instance.
It dies on fail.

Unlike Perl's C<open()> (nor C<IO::File>'s), I<$mode> is always required. 

=head2 PerlIO::Util-E<gt>known_layers()

Returns the known layer names.

=head2 I<FILEHANDLE>-E<gt>get_layers()

Returns the names of the PerlIO layers on I<FILEHANDLE>.

See L<PerlIO/Querying the layers of filehandles>.

=head2 I<FILEHANDLE>-E<gt>push_layer(I<layer> [ => I<arg>])

Equivalent to C<binmode(*FILEHANDLE, ':layer(arg)')>, but accepts any type of
I<arg>, e.g. a scalar reference to the C<:scalar> layer.

This method dies on fail. Otherwise, it returns I<FILEHANDLE>.

=head2 I<FILEHANDLE>-E<gt>pop_layer()

Equivalent to C<binmode(*FILEHANDLE, ':pop')>. It removes a top level layer
from I<FILEHANDLE>, but note that you cannot remove dummy layers such as
C<:utf8> or C<:flock>.

This method returns the name of the poped layer.

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to
E<lt>gfuji (at) cpan.orgE<gt>, or through the web interface at
L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<PerlIO::flock>, L<PerlIO::creat>, L<PerlIO::excl>, L<PerlIO::tee>, L<PerlIO::dir>

L<perlfunc/flock> for C<:flock>.

L<perlfunc/sysopen> for C<:creat> and C<:excl>.

L<PerlIO> for C<push_layer()> and C<pop_layer()>.

L<perliol> for implementation details.

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
