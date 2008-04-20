package PerlIO::Util;

use strict;

our $VERSION = '0.04';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

*IO::Handle::get_layers = \&PerlIO::get_layers;

1;
__END__

=head1 NAME

PerlIO::Util - A selection of general PerlIO utilities

=head1 VERSION

This document describes PerlIO::Util version 0.04

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

    STDOUT->pop_layer();

    print $s; # => foo

=head1 DESCRIPTION

C<PerlIO::Util> provides general PerlIO utilities: utility layers and utility
methods.

=head1 UTILITY LAYERS

=head2 :flock

C<:flock> is a dummy layer that provides an interface to C<flock()>.

It tries to lock the filehandle in C<open()> (or C<binmode()>) with
C<flock()> according to the open mode. That is, if a file is opened for writing,
C<:flock> attempts exclusive lock (using LOCK_EX). Otherwise, it attempts
shared lock (using LOCK_SH).

It waits until the lock is granted. If an arg like "non-blocking"
is suplied, the call of C<open()> fails when the lock cannot be granted.

For example:

	open IN, "<:flock", $file;               # tries shared lock, or waits
	                                         # until the lock is granted.
	open IN, "<:flock(blocking)", $file;     # ditto.
	open IN, "<:flock(non-blocking)", $file; # tries shared lock, or returns undef.

See L<perlfunc/flock>.

=head2 :creat

The C<:creat> dummy layer appends O_CREAT to the open flags.

See L<perlfunc/sysopen>.

=head2 :excl

the C<:excl> dummy layer appends O_EXCL to the open flags.

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

This method returns itself.

=head2 I<FILEHANDLE>-E<gt>pop_layer()

Equivalent to C<binmode(*FILEHANDLE, ':pop')>.

This method returns itself.

=head1 DEPENDENCIES

Perl 5.8.0 or later.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to
E<lt>gfuji (at) cpan.orgE<gt>, or through the web interface at
L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<perlfunc/flock>.

L<perlfunc/sysopen>.

L<PerlIO>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
