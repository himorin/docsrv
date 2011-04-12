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
    if (! defined($ext)) {$ext = 'html'; }
    $self->_throw_error('error/code', $ext, $err_id);
}

sub throw_error_user {
    my ($self, $err_id, $ext) = @_;
    if (! defined($ext)) {$ext = 'html'; }
    $self->_throw_error('error/user', $ext, $err_id);
}

################################################################## PRIVATE

sub _throw_error {
    my ($self, $fname, $ext, $err_id) = @_;
    PSMT->dbh->db_unlock_tables(PSMT::Constants::DB_UNLOCK_ABORT);

    PSMT->template->set_vars('error', $err_id);
    print PSMT->cgi->header();
    PSMT->template->process($fname, $ext, PSMT->template->vars);

    exit;
}


1;

__END__




