require PerlIO::Util;
__END__
=head1 NAME

PerlIO::dir - Reads directories

=head1 SYNOPSIS

	open my $dp, '<:dir', '.';

	binmode $dp, ':encoding(cp932)'; # OK

	my @dirs = <$dp>; # added "\n" at the end of the name
	chomp @dirs; # if necessary

	seek $dp, 0, 0;     # rewind
	my $pos = tell $dp;

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
