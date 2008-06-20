package PerlIO::fse;

use strict;

use PerlIO::Util ();

*import = \&PerlIO::Util::fse;

1;
__END__

=encoding utf-8

=head1 NAME

PerlIO::fse - Deals with Filesystem Encoding

=head1 SYNOPSIS

	# for Windows (including Cygwin)

	open my $io,  '<:fse', $utf8_filename;

	# Other systems
	$ENV{PERLIO_FSE} = 'EUC-JP'; # actually, UTF-8 by default
	# or
	use PerlIO::fse 'EUC-JP';

	open my $io, '<:fse', $utf8_filename;

	# or

	open my $io, "<:fse($encoding)", $utf8_filename;


=head1 DESCRIPTION

C<PerlIO::fse> mediates encodings between Perl and Filesystem.

=head1 SEE ALSO

L<PerlIO::Util>.

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
