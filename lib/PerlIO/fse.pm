package PerlIO::fse;
use strict;
require PerlIO::Util;
*import = \&PerlIO::Util::fse;
1;
__END__

=encoding utf-8

=head1 NAME

PerlIO::fse - Deals with Filesystem Encoding

=head1 SYNOPSIS

	# for Windows (including Cygwin)
	open my $io,  '<:fse', $filename;

	# Other systems
	$ENV{PERLIO_FSE} = $encoding; # UTF-8 is default
	# or
	use PerlIO::fse $encoding;

	open my $io, '<:fse', $filename;


=head1 DESCRIPTION

C<PerlIO::fse> mediates encodings between Perl and Filesystem. It converts
filenames into native forms if the filenames are utf8-flagged. Otherwise,
C<PerlIO::fse> does nothing, looking on it as native forms.

C<PerlIO::fse> attempts to get the filesystem encoding(C<fse>)
from C<$ENV{PERLIO_FSE}>, and if defined, it will be used. Or you can
C<use PerlIO::fse $encoding> directive to set C<fse>.

If you use Windows (or Cygwin), you need not to set C<$ENV{PERLIO_FSE}>
because the current codepage is detected automatically.
However, if C<$ENV{PERLIO_FSE}> is set, C<PerlIO::fse> will give it
priority.

When there is no encoding available, C<UTF-8> will be used.

This layer uses C<Encode> internally to convert encodings.

=head1 SEE ALSO

L<PerlIO::Util>.

L<Encode>.

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
