require PerlIO::Util;
__END__

=encoding utf-8

=head1 NAME

PerlIO::tee - Multiplex output layer

=head1 SYNOPSIS

	# XXX: the tee layer is EXPERIMENTAL

	open my $out, '>>:tee', $file, @sources;

	STDERR->push_layer(tee => $source);

=head1 EXAMPLE

Here is an minimal implementation of C<tee(1)>.

	#!/usr/bin/perl -w
	# Usage: $0 files...
	use strict;
	use PerlIO::Util;

	STDOUT->push_layer(tee => $_) for @ARGV;

	while(read STDIN, $_, 2**12){
		print;
	}
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
