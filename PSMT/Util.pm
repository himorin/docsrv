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

use Template;
use Encode;
use Digest::MD5;

@PSMT::Util::EXPORT = qw(
    filter_none
    filter_js
    filter_html_lb
    filter_html_nb
    filter_html
    filter_text
    filter_url_quote
    filter_path_url

    IpAddr
    GetHashString
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
    $var =~ s/([\\\'\"\/])/\\$1/g;
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

1;

__END__


