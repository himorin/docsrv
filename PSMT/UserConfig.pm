# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Per user configuration manipulation
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::UserConfig;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;
use PSMT::Label;
use PSMT::Access;
use PSMT::User;

%PSMT::UserConfig::EXPORT = qw(
    new

    Config
    ConfigReload

    ParamReset
    ParamUpdate
);

my %config;

my @class = ('number', 'enum', 'string', 'char', 'bool');

sub new {
    my ($self) = @_;
    $self->_read_defaults();
    $self->_read_user();
    return $self;
}

sub Config {
    my ($self) = @_;
    return \%config;
}

sub ConfigReload {
    my ($self) = @_;
    $self->_read_defaults();
    $self->_read_user();
}

sub ParamReset {
    my ($self, $param) = @_;
    if ($config{$param}->{is_default} == TRUE) {return TRUE; }
    my $uname = PSMT->user->get_uid();
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('profiles WRITE');
    my $sth = $dbh->prepare('DELETE FROM profiles WHERE uname = ? AND name = ?');
    if ($sth->execute($uname, $param) == 0) {return FALSE; }
    return TRUE;
}

sub ParamUpdate {
    my ($self, $param, $value) = @_;
    my $uname = PSMT->user->get_uid();
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('profiles WRITE');
    if ($config{$param}->{is_default} == TRUE) {
        # add
        my $sth = $dbh->prepare('INSERT INTO profiles (uname, name, value) VALUES (?, ?, ?)');
        if ($sth->execute($uname, $param, $value) == 0) {return FALSE; }
    } else {
        # update
        my $sth = $dbh->prepare('UPDATE profiles SET value = ? WHERE uname = ? AND name = ?');
        if ($sth->execute($value ,$uname, $param) == 0) {return FALSE; }
    }
    return TRUE;
}


#------------------------------------------------------------------------


sub _read_user {
    my ($self) = @_;
    my $uname = PSMT->user->get_uid();
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('profiles READ');
    my $sth = $dbh->prepare('SELECT * FROM profiles WHERE uname = ?');
    $sth->execute($uname);
    my ($ref, %def);
    while ($ref = $sth->fetchrow_hashref()) {
        if (! defined($config{$ref->{name}})) {next; }
        if ($config{$ref->{name}}->{enabled} != TRUE) {next; }

        %def = %{$config{$ref->{name}}};
        if ($def{class} eq 'enum') {
            # if target is enum, check valid
            if (index($def{enumval}, ',' . $ref->{value} . ',') > -1) {
                $config{$ref->{name}}->{value} = $ref->{value};
                $config{$ref->{name}}->{is_default} = FALSE;
            }
        } elsif ($def{class} eq 'bool') {
            if ($ref->{value} ne '0') {$config{$ref->{name}}->{value} = 1; }
            else {$config{$ref->{name}}->{value} = 0; }
            $config{$ref->{name}}->{is_default} = FALSE;
        } else {
            $config{$ref->{name}}->{value} = $ref->{value};
            $config{$ref->{name}}->{is_default} = FALSE;
        }
    }
}

sub _read_defaults {
    my ($self) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('setting READ');
    my $sth = $dbh->prepare('SELECT * FROM setting');
    $sth->execute();
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        $config{$ref->{name}} = $ref;
        $config{$ref->{name}}->{value} = $ref->{default_value};
        $config{$ref->{name}}->{is_default} = TRUE;
        if ($ref->{class} eq 'enum') {
            $config{$ref->{name}}->{enum} = split(/,/, $ref->{enumval});
        }
    }
}


1;

__END__


