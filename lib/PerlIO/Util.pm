package PerlIO::Util;

use strict;

our $VERSION = '0.51';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

*IO::Handle::get_layers = \&PerlIO::get_layers;

sub open{
	if(@_ < 3){
		require Carp;
		Carp::croak('Usage: PerlIO::Util->open($mode, @args)');
	}
	my $anonio;
	unless(CORE::open $anonio, $_[1], @_[2 .. $#_]){
		require Carp;
		Carp::croak('Cannot open(',join(', ', @_[1 .. $#_]), "): $!");
	}
	return bless $anonio => 'IO::Handle';
}

1;
__END__

=encoding utf-8

=head1 NAME

PerlIO::Util - A selection of general PerlIO utilities

=head1 VERSION

This document describes PerlIO::Util version 0.51

=head1 SYNOPSIS

    use PerlIO::Util;

    # utility layers

    open $in, "+<:flock", ...; # with flock(IN, LOCK_EX)

    open $in, "+<:creat :excl", ...; # with O_CREAT | O_EXCL

    open $out, ">:tee", $file, \$scalar, \*STDERR;
    print $out "foo"; # print to $file, $scalar and *STDERR

    # utility routines

    $fh = PerlIO::Util->open('<', $file); # it dies on fail

    *STDOUT->push_layer(scalar => \$s); # it dies on fail
    print "foo";

    print *STDOUT->pop_layer(); # => scalar
    print $s; # => foo

=head1 DESCRIPTION

C<PerlIO::Util> provides general PerlIO utilities: utility layers and utility
methods.

Utility layers are a part of C<PerlIO::Util>, but you don't need to
say C<use PerlIO::Util> for loading them. They will be automatically loaded.

=head1 UTILITY LAYERS

=head2 :flock 

Easy interface to C<flock()>.

See L<PerlIO::flock>.

=head2 :creat

Use of O_CREAT without C<Fcntl>.

See L<PerlIO::creat>.

=head2 :excl

Use of O_EXCL without C<Fcntl>.

See L<PerlIO::excl>.

=head2 :tee

Multiplex output layer.

See L<PerlIO::tee>.

=head2 :dir

PerlIO interface to directory functions.

See L<PerlIO::dir>.

=head2 :reverse

Reverse input iterator.

See L<PerlIO::reverse>.

=head2 :fse

Mediation of filesystem encoding.

See L<PerlIO::fse>.

=head1 UTILITY METHODS

=head2 PerlIO::Util->open(I<mode>, I<args>)

Calls built-in C<open()>, and returns an anonymus C<IO::Handle> instance.
It dies on fail.

Unlike Perl's C<open()> (nor C<IO::File>'s), I<mode> is always required. 

=head2 PerlIO::Util->known_layers( )

Returns the known layer names.

=head2 I<FILEHANDLE>->get_layers( )

Returns the names of the PerlIO layers on I<FILEHANDLE>.

See L<PerlIO/Querying the layers of filehandles>.

=head2 I<FILEHANDLE>->push_layer(I<layer> [ => I<arg>])

Almost equivalent to C<binmode(FILEHANDLE, ':layer(arg)')>, but accepts
any type of I<arg>, e.g. a scalar reference to the C<:scalar> layer.

This method dies on fail. Otherwise, it returns I<FILEHANDLE>.

=head2 I<FILEHANDLE>->pop_layer( )

Equivalent to C<binmode(FILEHANDLE, ':pop')>. It removes a top level layer
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

L<PerlIO::flock>, L<PerlIO::creat>, L<PerlIO::excl>, L<PerlIO::tee>,
L<PerlIO::dir>, L<PerlIO::reverse>, L<PerlIO::fse>.

L<PerlIO> for C<push_layer()> and C<pop_layer()>.

L<perliol> for implementation details.

L<perlfunc/open>.

L<perlopentut>.

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
