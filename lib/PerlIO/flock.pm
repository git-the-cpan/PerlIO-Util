require PerlIO::Util;
__END__

=head1 NAME

PerlIO::flock - Easy flock() interface

=head1 SYNOPSIS

	open my $in,  '< :flock', $file; # shared lock
	open my $out, '+<:flock', $file; # exclusive lock

	binmode($fh, ':flock(blocking)');
	binmode($fh, ':flock(non-blocking)');

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
