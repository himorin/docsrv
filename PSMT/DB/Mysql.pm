# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - DB Driver - MySQL
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::DB::Mysql;

use strict;

use PSMT::Constants;
use PSMT::DB;

use base qw(PSMT::DB);

sub new {
    my ($class, $user, $pass, $host, $dbname, $port, $sock) = @_;

    my $dsn = "DBI:mysql:host=$host;database=$dbname";
    $dsn .= ";port=$port" if $port;
    $dsn .= ";mysql_socket=$sock" if $sock;
    my %attrs = (
        mysql_enable_utf8 => 1,
    );
    my $self = $class->db_new_conn($dsn, $user, $pass, \%attrs);

    $self->{private_table_locked} = "";
    bless($self, $class);
    $self->do("SET NAMES utf8");
    return $self;
}

sub db_last_key {
    my ($self) = @_;
    my ($last_insert_id) = $self->selectrow_array('SELECT LAST_INSERT_ID()');
    return $last_insert_id;
}

sub db_lock_tables {
    my ($self, @tables) = @_;
    if ($self->{private_table_locked} ne '') {
        PSMT->error->throw_error_code("already_locked",
            {
                current => $self->{private_table_locked},
                new => join(', ', @tables),
            });
    } else {
        $self->do('LOCK TABLES ' . join(', ', @tables));
        $self->{private_table_locked} = join(', ', @tables);
    }
}

sub db_unlock_tables {
    my ($self, $abort) = @_;
    if ($self->{private_table_locked} eq '') {
        return if defined($abort);
        PSMT->error->throw_error_code("not_locked");
    } else {
        $self->do('UNLOCK TABLES');
        $self->{private_table_locked} = '';
    }
}

################################################################## PRIVATE


1;

__END__




