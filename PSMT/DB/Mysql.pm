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
    push(@tables, split(/,/, $self->{private_table_locked}));
    my (%tbl, @ctbl, $ccmd);
    foreach (@tables) {
        $ccmd = lc($_);
        @ctbl = split(/ /, $ccmd);
        if (defined($tbl{$ctbl[0]})) {
            if ($ctbl[1] eq 'write') {$tbl{$ctbl[0]} = 'write'; }
        } else {
            $tbl{$ctbl[0]} = ($ccmd eq 'read') ? 'read' : 'write';
        }
    }
    $ccmd = '';
    foreach (keys %tbl) {
        $ccmd .= ', ' . $_ . ' ' . $tbl{$_};
    }
    $ccmd = substr($ccmd, 2);
    $self->do('LOCK TABLES ' . $ccmd);
    $self->{private_table_locked} = $ccmd;
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




