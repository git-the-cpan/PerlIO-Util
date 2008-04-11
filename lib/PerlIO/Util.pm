package PerlIO::Util;

use strict;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

PerlIO::Util - A selection of general-utility PerlIO layers

=head1 VERSION

This document describes PerlIO::Util version 0.01


=head1 SYNOPSIS

    use PerlIO::Util;

    # dummy layers

    open IN, "< :flock", ...; # with flock(IN, LOCK_SH)
    open IN, "+<:flock", ...; # with flock(IN, LOCK_EX)

    open IN, "+<:creat", ...; # with O_CREAT
    open IN, "> :excl",  ...; # with O_EXCL

    # utility subroutines

    my @layers = PerlIO::Util->known_layers();

    # extended PerlIO::Layer methods

    say PerlIO::Layer->find('crlf')->name; # says "crlf"

=head1 DESCRIPTION

C<PerlIO::Util> provides utilities for C<open()> and PerlIO layers.

These utilities is devided into three categories: PerlIO layers, utility
methods and extended PerlIO::Layer methods.

=head1 PERLIO LAYERS

=head2 :flock

The C<:flock> is a dummy layer that doesn't exist on the layer stack,
which provides an interface to C<flock()>.

After C<open()>, it locks the filehandle in C<open()> (or C<binmode()>) by
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

see L<perlfunc/flock>.

=head2 :creat

The C<:creat> dummy layer appends O_CREAT to the open flags.

see L<perlfunc/sysopen>.

=head2 :excl

the C<:excl> dummy layer appends O_EXCL to the open flags.

see L<perlfunc/sysopen>.

=head1 UTILITY METHODS

=head2 PerlIO::Util-E<gt>known_layers()

Retuns known layers as string list.

=head1 EXTENDED PerlIO::Layer METHODS

=head2 $layer-E<gt>name()

Retuns the name of I<$layer> that will be obtained by
C<< PerlIO::Layer->find($name) >>.

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
