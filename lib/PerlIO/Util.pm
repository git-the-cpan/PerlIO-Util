package PerlIO::Util;

use strict;

our $VERSION = '0.07';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

*IO::Handle::get_layers = \&PerlIO::get_layers;

1;
__END__

=head1 NAME

PerlIO::Util - A selection of general PerlIO utilities

=head1 VERSION

This document describes PerlIO::Util version 0.07

=head1 SYNOPSIS

    use PerlIO::Util;

    # utility layers

    open IN, "< :flock", ...; # with flock(IN, LOCK_SH)
    open IN, "+<:flock", ...; # with flock(IN, LOCK_EX)

    open IN, "+<:creat", ...; # with O_CREAT
    open IN, "> :excl",  ...; # with O_EXCL

    # utility routines

    STDOUT->push_layer(scalar => \my $s);
    print "foo";

    print STDOUT->pop_layer(); # => scalar

    print $s; # => foo

=head1 DESCRIPTION

C<PerlIO::Util> provides general PerlIO utilities: utility layers and utility
methods.

C<:flock>, C<:creat> and C<:excl> are pseudo layers that don't exist on the layer
stack.

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

	open IN, "<:flock", $file;               # tries shared lock, or waits
	                                         # until the lock is granted.
	open IN, "<:flock(blocking)", $file;     # ditto.

	open IN, "<:flock(non-blocking)", $file; # tries shared lock, or returns undef.
	open IN, "<:flock(LOCK_NB)", $file;      # ditto.

See L<perlfunc/flock>.

=head2 :creat

=head2 :excl

They append O_CREAT or O_EXCL to the open flags.

With C<:creat> and C<:excl>, you can emulate a part of C<sysopen()> without
C<Fcntl>.

Here are things you can do with them:

To open a file for update, creating a new file which must
not previously exist:

	my $fh = PerlIO::Util->open('+< :excl :creat', $file);

To open a file for update, creating a new file if necessary:

	my $fh = PerlIO::Util->open('+< :creat', $file);


See L<perlfunc/sysopen>.

=head1 UTILITY METHODS

=head2 PerlIO::Util-E<gt>known_layers()

Retuns the known layer names.

=head2 I<FILEHANDLE>-E<gt>get_layers()

Returns the names of the PerlIO layers on I<FILEHANDLE>.

See L<PerlIO/Querying the layers of filehandles>.

=head2 I<FILEHANDLE>-E<gt>push_layer(I<layer> [ => I<arg>])

Equivalent to C<binmode(*FILEHANDLE, ':layer(arg)')>, but accepts any type of
I<arg>, e.g. a scalar reference to the C<scalar> layer.

This method dies on fail. Otherwise, it returns I<FILEHANDLE>.

=head2 I<FILEHANDLE>-E<gt>pop_layer()

Equivalent to C<binmode(*FILEHANDLE, ':pop')>.

This method returns the name of the poped layer.

=head1 DEPENDENCIES

Perl 5.8.0 or later.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to
E<lt>gfuji (at) cpan.orgE<gt>, or through the web interface at
L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<perlfunc/flock> for C<:flock>.

L<perlfunc/sysopen> for C<:creat> and C<:excl>.

L<PerlIO> for C<push_layer()> and C<pop_layer()>.

L<perliol> for implementation details.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
