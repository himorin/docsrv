# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Error handlers (to output)
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Error;

use strict;

use base qw(Exporter);

use PSMT::Constants;
use PSMT::Template;

%PSMT::Config::EXPORT = qw(
    new

    throw_error_user
    throw_error_code
);

sub new {
    my ($this) = @_;
    return $this;
}

sub throw_error_code {
    my ($self, $err_id, $ext) = @_;
    if (! defined($ext)) {$ext = ''; }
    $self->_throw_error('error/code', $ext, $err_id);
}

sub throw_error_user {
    my ($self, $err_id, $ext) = @_;
    if (! defined($ext)) {$ext = ''; }
    $self->_throw_error('error/user', $ext, $err_id);
}

################################################################## PRIVATE

sub _throw_error {
    my ($self, $fname, $ext, $err_id) = @_;
    my @formats = @{AVAIL_FORMATS->{error}};
    if (! defined($ext)) {$ext = PSMT->cgi()->param('format'); }
    my $fmt = '';
    foreach (@formats) {if ($_ eq $ext) {$fmt = $ext; } }
    if ($fmt eq '') {$fmt = $formats[0]; }
    PSMT->dbh->db_transaction_rollback(TRUE);
    PSMT->template->set_vars('error', $err_id);
    PSMT->template->process($fname, $fmt, PSMT->template->vars);
    exit;
}


1;

__END__




