require PerlIO::Util;
__END__
=head1 NAME

PerlIO::reverse - Reads lines backward

=head1 SYNOPSIS

	open my $rev, '<:reverse', $file;
	print while <$rev>; # print contents reversely

=head1 EXAMPLE

Here is an minimal implementation of C<tac(1)>.

	#!/usr/bin/perl -w
	# Usage: $0 files...
	use open IN => ':reverse';
	print while <>;
	__END__

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
