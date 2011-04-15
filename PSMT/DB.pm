# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - DB interface part
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::DB;

use strict;

use DBI;
use base qw(DBI::db);

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;

my @prepare_sql;

BEGIN {
    if ($ENV{SERVER_SOFTWARE}) {
        require CGI::Carp;
        CGI::Carp->import('fatalsToBrowser');
    }
}

sub connect {
    my $config = PSMT->config->GetHash();
    return _connect(
        $config->{'db_driver'},
        $config->{'db_host'},
        $config->{'db_name'},
        $config->{'db_port'},
        $config->{'db_sock'},
        $config->{'db_user'},
        $config->{'db_pass'},
    )
}

sub _connect {
    my ($driver, $host, $dbname, $port, $sock, $user, $pass) = @_;
    my $pkg_module = DB_MODULE->{lc($driver)}->{db};

    eval ("require $pkg_module")
        || die ("'$driver' is not a valid DB module. " . $@);
    my $dbh = $pkg_module->new($user, $pass, $host, $dbname, $port, $sock);
    return $dbh;
}

sub db_server_version {
    my ($self) = @_;
    return $self->get_info(18);
}

sub db_last_key {
    my ($self, $table, $column) = @_;
    return $self->last_insert_id(
        PSMT->config->GetParam('db_name'), undef, $table, $column);
}

sub db_transaction_start {
    my ($self) = @_;
    if ($self->{private_db_in_transaction}) {
        PSMT->error->throw_error_code("nested_transaction");
    } else {
        $self->begin_work();
        $self->{private_db_in_transaction} = 1;
    }
}

sub db_transaction_commit {
    my ($self) = @_;
    if (! $self->{private_db_in_transaction}) {
        PSMT->error->throw_error_code("not_in_transaction");
    } else {
        $self->commit();
        $self->{private_db_in_transaction} = 0;
    }
}

sub db_transaction_rollback {
    my ($self) = @_;
    if (! $self->{private_db_in_transaction}) {
        PSMT->error->throw_error_code("not_in_transaction");
    } else {
        $self->rollback();
        $self->{private_db_in_transaction} = 0;
    }
}

sub db_new_conn {
    my ($class, $dsn, $user, $pass, $attr) = @_;
    $attr = {
        RaiseError => 0,
        AutoCommit => 1,
        PrintError => 0,
        ShowErrorStatement => 1,
        HandleError => \&_handle_error,
        TaintIn => 1,
        FetchHashKeyName => 'NAME',
    } if (! defined($attr));
    my $self = DBI->connect($dsn, $user, $pass, $attr)
        or die "\nCan't connect to the DB.\n$DBI::errstr\n";
    $self->{RaiseError} = 1;
    $self->{private_db_in_transaction} = 0;
    bless($self, $class);
    return $self;
}

sub prepare {
    my ($self, $sql, @opts) = @_;
    push(@prepare_sql, $sql);
    return $self->SUPER::prepare($sql, @opts);
}

sub DebugSQL {
    my ($self) = @_;
    PSMT->template->set_vars('debug_sql', \@prepare_sql);
}


################################################################## PRIVATE


sub _handle_error {
    require Carp;
    my $db_err_maxlen = PSMT->config->GetParam('db_err_maxlen');
    if (($db_err_maxlen > 0) && ($db_err_maxlen < length($_[0]))) {
        $_[0] = substr($_[0], 0, $db_err_maxlen / 2) . ' ... ' .
                substr($_[0], - $db_err_maxlen / 2);
        $_[0] = Carp::longmess($_[0]);
    }
    return 0;
}

1;

__END__



