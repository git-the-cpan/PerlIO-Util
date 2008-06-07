require PerlIO::Util;
__END__
=head1 NAME

PerlIO::reverse - Reads lines backward

=head1 SYNOPSIS

	open my $rev, '<:reverse', $file;
	print while <$rev>; # print contents reversely

=head1 SYNOPSIS

The C<:reverse> layer reads lines backward like C<tac(1)>.

=head1 EXAMPLE

Here is an minimal implementation of C<tac(1)>.

	#!/usr/bin/perl -w
	# Usage: $0 files...
	use open IN => ':reverse';
	print while <>;
	__END__

=head1 NOTE

=over 4

=item *

This layer cannot deal with unseekable filehandles and layers: tty,
C<:gzip>, C<:dir>, etc.

=item *

This layer is partly imcompatible with Win32 system. You have to call
B<binmode($fh)> before pushing it dynamically.

=back

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
