
=encoding utf-8

=head1 NAME

PerlIO::Util - PerlIOに関するユーティリティ集

=head1 VERSION

本ドキュメントはC<PerlIO::Util>のバージョン0.49_01を説明する。

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

C<PerlIO::Util>はPerlIOに関するユーティリティレイヤとユーティリティメソッドを
提供するモジュールである。

ユーティリティレイヤはC<PerlIO::Util>の一部だが，使用に際してC<use PerlIO::Util>
と書く必要はない。PerlIOはレイヤを自動的にロードする。

=head1 UTILITY LAYERS

=head2 :flock 

C<flock()>に対する簡易なインターフェイスを提供する

See L<PerlIO::flock>.

=head2 :creat

C<Fcntl>を用いずに，O_CREATを使用する

See L<PerlIO::creat>.

=head2 :excl

C<Fcntl>を用いずに，O_EXCLを使用する

See L<PerlIO::excl>.

=head2 :tee

複数のファイルハンドルに同時に出力する

See L<PerlIO::tee>.

=head2 :dir

PerlIOインターフェイスでディレクトリを読む

See L<PerlIO::dir>.

=head2 :reverse

ファイルを逆順に読む

See L<PerlIO::reverse>.

=head2 :fse

ファイルシステムエンコーディングを扱う

=head1 UTILITY METHODS

=head2 PerlIO::Util-E<gt>open(I<mode>, I<args>)

ビルトイン関数のC<open()>を呼び出し，C<IO::Handle>オブジェクトを返す。
C<open()>に失敗すると致命的エラーとなる。

PerlのC<open()>と異なり（またC<IO::File>のC<open()>とも異なり），I<mode>は
常に必須である。

=head2 PerlIO::Util->known_layers( )

定義済みのPerlIOレイヤの名前を返す。

=head2 I<FILEHANDLE>-E<gt>get_layers( )

I<FILEHANDLE>のPerlIOレイヤの名前を返す。
これはI<PerlIO::get_layers(I<FILEHANDLE>)>の別名である。

See L<PerlIO/Querying the layers of filehandles>.

=head2 I<FILEHANDLE>-E<gt>push_layer(I<layer> [ => I<arg>])

C<binmode(FILEHANDLE, ':layer(arg)')>とほぼ同じだが，I<arg>はどんな
データ型でもよい。たとえば，C<:scalar>に対してスカラリファレンスを与えることができる。

このメソッドは失敗すると致命的エラーとなる。成功したときはI<FILEHANDLE>を返す。

=head2 I<FILEHANDLE>-E<gt>pop_layer( )

C<binmode(FILEHANDLE, ':pop)>に等しい。これはI<FILEHANDLE>の最上位の
レイヤを取り除く。なお，C<:utf8>やC<:flock>のようなダミーレイヤを取り除くことはできない。

このメソッドは実際に取り除いたレイヤの名前を返す。

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

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji (at) cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji (at) cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
