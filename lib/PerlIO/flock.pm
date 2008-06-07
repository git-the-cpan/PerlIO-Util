require PerlIO::Util;
__END__

=head1 NAME

PerlIO::flock - Easy flock() interface

=head1 SYNOPSIS

	open my $in,  '< :flock', $file; # shared lock
	open my $out, '+<:flock', $file; # exclusive lock

	binmode($fh, ':flock(blocking)');
	binmode($fh, ':flock(non-blocking)');

=head1 DESCRIPTION

The C<:flock> layer provides an interface to C<flock()>.

It tries to lock the filehandle with C<flock()> according to the open mode.
That is, if a file is opened for writing, C<:flock> attempts exclusive lock
(using LOCK_EX). Otherwise, it attempts shared lock (using LOCK_SH).

It waits until the lock is granted. If an argument C<non-blocking> (or
C<LOCK_NB>) is suplied, the call of C<open()> (or C<binmode()>) fails when
the lock cannot be granted.

=head1 EXAMPLE

	# tries shared lock, or waits until the lock is granted
	open IN, "<:flock", $file;
	open IN, "<:flock(blocking)", $file;     # ditto.

	# tries shared lock, or returns undef
	open IN, "<:flock(non-blocking)", $file; 
	open IN, "<:flock(LOCK_NB)", $file;      # ditto.

=head1 SEE ALSO

L<PerlIO::Util>.

L<perlfunc/flock>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
