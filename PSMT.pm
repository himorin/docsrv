# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for PSMT - Master module
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT;

use strict;

use base qw(Exporter);

use PSMT::Config;
use PSMT::Constants;
use PSMT::CGI;
use PSMT::DB;
#use PSMT::Error;
#use PSMT::File;
use PSMT::NetLdap;
use PSMT::Template;
use PSMT::User;
#use PSMT::Util;

%PSMT::EXPORT = qw(
    new

    request

    cgi
    config
    template
    dbh
    user
    error
    ldap
);

our $_request = {};

sub new {
    my ($this) = @_;
    binmode STDOUT, ':utf8';
    return $this;
}

sub request {
    return $_request;
}

sub cgi {
    my ($this) = @_;
    $this->request->{cgi} ||= new PSMT::CGI;
    return $this->request->{cgi};
}

sub config {
    my ($this) = @_;
    $this->request->{config} ||= new PSMT::Config;
    return $this->request->{config};
}

sub template {
    my ($this) = @_;
    $this->request->{template} ||= new PSMT::Template;
    return $this->request->{template};
}

sub dbh {
    my $this = shift;
    $this->request->{dbh} ||= new PSMT::DB::connect();
    return $this->request->{dbh};
}

sub user {
    my $this = shift;
    $this->request->{user} ||= new PSMT::User;
    return $this->request->{user};
}

sub error {
    my $this = shift;
    $this->request->{error} ||= new PSMT::Error;
    return $this->request->{error};
}

sub ldap {
    my $this = shift;
    $this->request->{ldap} ||= new PSMT::NetLdap;
    return $this->request->{ldap};
}

################################################################## PRIVATE

sub _cleanup {
    my $this = shift;
    my $dbh = request()->{dbh};
    $dbh->disconnect if $dbh;
    undef $_request;
}

sub END {
    _cleanup();
}

1;

__END__




