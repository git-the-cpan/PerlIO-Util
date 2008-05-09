require PerlIO::Util;
__END__

=encoding utf-8

=head1 NAME

PerlIO::tee - Multiplex output layer

=head1 SYNOPSIS

	open my $out, '>>:tee', @files_and_filehandles;

	STDERR->push_layer(tee => $file_or_filehandle);

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
