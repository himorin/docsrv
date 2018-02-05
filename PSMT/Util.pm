# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Utility functions
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Util;

use strict;

use PSMT::Constants;
use PSMT::Config;

use Template;
use Encode;
use Digest::MD5;
use Text::Markdown;
use MIME::Types;

@PSMT::Util::EXPORT = qw(
    filter_none
    filter_js
    filter_html_lb
    filter_html_nb
    filter_html
    filter_text
    filter_url_quote
    filter_path_url
    filter_markdown

    IpAddr
    StrToIpaddr
    GetHashString
    ValidateEncoding
    ValidateName

    AddShortDesc
    GetLastFileId

    MakeReverseHash
    MakeReverseHashByKey
    MergeArrayAnd
    MergeArrayOr
    MergeHashAnd
    MergeHashOr

    GetMimeType
    IsPreview
);

sub StrToIpaddr {
    my ($str) = @_;
    my $addr = sprintf('%08x', $str);
    $str  = hex(substr($addr, 0, 2)) . '.';
    $str .= hex(substr($addr, 2, 2)) . '.';
    $str .= hex(substr($addr, 4, 2)) . '.';
    $str .= hex(substr($addr, 6, 2));
    return $str;
}

sub IpAddr {
    my $src = $ENV{'REMOTE_ADDR'};
    my @srcs = split(/\./, $src);
    my $addr = $srcs[0];
    $addr *= 256;
    $addr += $srcs[1];
    $addr *= 256;
    $addr += $srcs[2];
    $addr *= 256;
    $addr += $srcs[3];
    return $addr;
}

sub GetHashString {
    my ($self, $string) = @_;
    my $ctx = Digest::MD5->new;
    utf8::encode($string);
    $ctx->add(time() . $string);
    my $hash = $ctx->b64digest;
    $hash =~ s/\+/\_/g;
    $hash =~ s/\//-/g;
    return $hash;
}

sub filter_none {
    return $_[0];
}

sub filter_js {
    my ($var) = @_;
#   not sure but rejected \' (error on json parsing)
    $var =~ s/([\\\"\/])/\\$1/g;
    $var =~ s/\n/\\n/g;
    $var =~ s/\r/\\r/g;
    $var =~ s/\@/\\x40/g; # anti-spam for email addresses
    return $var;
}

sub filter_html_lb {
    my ($var) = @_;
    $var =~ s/\r\n/\&#013;/g;
    $var =~ s/\n\r/\&#013;/g;
    $var =~ s/\r/\&#013;/g;
    $var =~ s/\n/\&#013;/g;
    return $var;
}

sub filter_html_nb {
    my ($var) = @_;
    $var =~ s/ /\&nbsp;/g;
    $var =~ s/-/\&#8209;/g;
    return $var ;
}

sub filter_html {
    my ($var) = Template::Filters::html_filter(@_);
    $var =~ s/\@/\&#64;/g;
    return $var;
}

sub filter_text {
    my ($var) = @_;
    $var =~ s/<[^>]*>//g;
    $var =~ s/\&#64;/@/g;
    $var =~ s/\&lt;/</g;
    $var =~ s/\&gt;/>/g;
    $var =~ s/\&quot;/\"/g;
    $var =~ s/\&amp;/\&/g;
    return $var;
}

sub filter_markdown {
    my ($var) = @_;
    my $obj_md = new Text::Markdown;
    return $obj_md->markdown($var);
}

sub filter_url_quote {
    my ($var) = @_;
    # IF utf8 mode, must utf8::encode 'var'
    utf8::encode($var) if utf8::is_utf8($var);
    $var =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    return $var;
}

sub filter_path_url {
    my ($var) = @_;
    # IF utf8 mode, must utf8::encode 'var'
    $var =~ s/^\///g;
    $var =~ s/\/$//g;
    utf8::encode($var) if utf8::is_utf8($var);
    $var =~ s/([^a-zA-Z0-9_\-.\/])/uc sprintf("%%%02x",ord($1))/eg;
    return $var;
}

sub AddShortDesc {
    my ($self, $ref) = @_;
    if (! defined($ref->{description})) {return $ref; }
    $ref->{short_description} = $ref->{description};
    if ($ref->{short_description} =~ /[\r\n]/) {
        $ref->{short_description} =~ /^#* *(.+?)[\r\n]/;
        $ref->{short_description} = $1;
    } else {
        $ref->{short_description} =~ /^#* *(.+)/;
        $ref->{short_description} = $1;
    }
    return $ref;
}

sub ValidateEncoding {
    my ($self, $str) = @_;
    while (length($str) > 0){
        if ($str =~ /^[\x00-\x7f]/) {$str = substr($str, 1); }
        elsif ($str =~ /^[\xC2-\xDF][\x80-\xBF]/) {$str = substr($str, 2); }
        elsif ($str =~ /^[\xE0-\xEF][\x80-\xBF][\x80-\xBF]/)
            {$str = substr($str, 3); }
        elsif ($str =~ /^[\xF0-\xF7][\x80-\xBF][\x80-\xBF][\x80-\xBF]/)
            {$str = substr($str, 4); }
        elsif ($str =~ /^[\xF8-\xFB][\x80-\xBF][\x80-\xBF][\x80-\xBF][\x80-\xBF]/)
            {$str = substr($str, 5); }
        elsif ($str =~ /^[\xFC-\xFD][\x80-\xBF][\x80-\xBF][\x80-\xBF][\x80-\xBF][\x80-\xBF]/)
            {$str = substr($str, 6); }
        else {return length($str); }
    }
    return 0;
}

sub ValidateName {
    my ($self, $str) = @_;
    # invalid if heading or tailing charactor
    if (index(INVALID_HEAD_TAIL, substr($str, 0, 1)) > -1) {return 'head_char'; }
    if (index(INVALID_HEAD_TAIL, substr($str, -1)) > -1) {return 'tail_char'; }
    # double white-sp is invalid
    if (index($str, '  ') > -1) {return 'double_white_sp'; }
    return undef;
}

sub GetLastFileId {
    my ($self, $arr) = @_;
    my $lastid = undef;
    my $lastup = undef;
    foreach (@$arr) {
        if (! (defined($_->{fileid}) && defined($_->{uptime}))) {next; }
        if (! defined($lastid)) {
            $lastid = $_->{fileid};
            $lastup = $_->{uptime};
            next;
        }
    }
    return $lastid;
}

sub MakeReverseHash {
    my ($self, $ref) = @_;
    my %hash;
    foreach (keys(%$ref)) {
        if (defined($hash{$ref->{$_}})) {
            push(@{$hash{$ref->{$_}}}, $_);
        } else {
            my @arr = ($_);
            $hash{$ref->{$_}} = \@arr;
        }
    }
    return \%hash;
}

# build reversed hash by $ref->{$key}, $hash->{$key} = $orig-key;
sub MakeReverseHashByKey {
    my ($self, $ref, $key) = @_;
    my %hash;
    foreach (keys(%$ref)) {
        if (defined($hash{$ref->{$_}->{$key}})) {
            push(@{$hash{$ref->{$_}->{$key}}}, $_);
        } else {
            my @arr = ($_);
            $hash{$ref->{$_}->{$key}} = \@arr;
        }
    }
    return \%hash;
}

sub MergeArrayAnd {
    my ($self, $arr1, $arr2) = @_;
    my (%hash, @res);
    foreach (@$arr1) {$hash{$_} = 1; }
    foreach (@$arr2) {if (defined($hash{$_})) {push(@res, $_); } }
    return \@res;
}

sub MergeArrayOr {
    my ($self, $arr1, $arr2) = @_;
    my (@arr, @res, $last);
    @arr = @$arr1;
    push(@arr, @$arr2);
    $last = shift(@arr);
    push(@res, $last);
    foreach (sort @arr) {
        if ($last ne $_) {$last = $_; push(@res, $last); }
    }
    return \@res;
}

sub MergeHashAnd {
    my ($self, $hash1, $hash2) = @_;
    my %hash;
    foreach (keys %$hash1) {
        if (defined($hash2->{$_})) {$hash{$_} = $hash1->{$_}; }
    }
    return \%hash;
}

sub MergeHashOr {
    my ($self, $hash1, $hash2) = @_;
    my %hash;
    foreach (keys %$hash1) {$hash{$_} = $hash1->{$_}; }
    foreach (keys %$hash2) {
        if (! defined($hash{$_})) {$hash{$_} = $hash2->{$_}; }
    }
    return \%hash;
}

sub GetMimeType {
    my ($self, $ext) = @_;
    my $mime = MIME::Types->new();
    my $fmime = $mime->mimeTypeOf($ext);
    if (defined($fmime)) {return lc($fmime); }
    return DEF_CONTENTTYPE;
}

sub IsPreview {
    my ($self, $mime) = @_;
    my $tmp = IS_PREVIEW;
    foreach (keys %$tmp) {
        if (index($mime, $_) == 0) {
            if ((PSMT::Constants::IS_PREVIEW->{$_} eq 'libreoffice') &&
                (PSMT::Config->GetParam('libreoffice') eq '')) {
                next;
            }
            return $_;
        }
    }
    return FALSE;
}

1;

__END__


