# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for CGI wrapper
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::CGI;

use strict;

use CGI qw(
    -no_xhtml
    :unique_headers
    :private_tempfiles
);
use base qw(CGI);

use PSMT::Constants;
use PSMT::Config;
use PSMT::Error;

$| = 1; # disabling output buffering

sub DESTROY {};

sub new {
    my ($ic, @args) = @_;
    my $class = ref($ic) || $ic;
    my $self = $class->SUPER::new(@args);

    $self->{psmt_cookie} = [];
    $self->charset('UTF-8');

    my $err = $self->cgi_error;
    if ($err) {
        print $self->header(-status => $err);
        die "CGI PARSER ERROR: $err";
    }

    return $self;
}

sub param {
    my ($self, @args) = @_;
    local $CGI::LIST_CONTEXT_WARN = 0;
    if (scalar(@args) == 1) {
        # for parameter valur request, check utf8 flag
        my @result = $self->SUPER::param(@args);
        for (0 ... $#result) {
            if (! utf8::is_utf8($result[$_])) {utf8::decode($result[$_]); }
        }
        return wantarray ? @result : $result[0];
    }
    return $self->SUPER::param(@args);
}

sub header {
    my $self = shift;
    if (scalar(@{$self->{psmt_cookie}})) {
        if (scalar(@_) == 1) {
            unshift(@_, '-type' => shift(@_));
        }
        unshift(@_, '-cookie' => $self->{psmt_cookie});
    }
    return $self->SUPER::header(@_) || "";
}

sub add_cookie {
    my $self = shift;

    my %param;
    my ($key, $value);
    while ($key = shift) {
        $value = shift;
        $param{$key} = $value;
    }

    if (! (defined($param{'-name'}) && defined($param{'-value'}))) {
        return;
    }
    $param{'-path'} = PSMT->config->GetParam('cookie_path')
        if PSMT->config->GetParam('cookie_path');
    $param{'-domain'} = PSMT->config->GetParam('cookie_domain')
        if PSMT->config->GetParam('cookie_domain');
    $param{'-expires'} = PSMT->config->GetParam('cookie_expires')
        if PSMT->config->GetParam('cookie_expires') &&
           (! defined($param{'-expires'}));

    my @parr;
    foreach (keys(%param)) {
        unshift(@parr, $_ => $param{$_});
    }

    push(@{$self->{psmt_cookie}}, $self->cookie(@parr));
}

sub remove_cookie {
    my $self = shift;
    my ($name) = (@_);
    $self->add_cookie('-name'    => $name,
                      '-expires' => 'Tue, 01-Jan-1980 00:00:00 GMT',
                      '-value'   => 0);
}

sub is_windows {
    my $self = shift;
    if ($self->user_agent() =~ /Windows/) {return TRUE; }
    return FALSE;
}

################################################################## PRIVATE

1;

__END__




