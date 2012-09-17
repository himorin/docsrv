# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Attribute manipulation
#
# Copyright (C) 2012 - : IPMU/PFS
# Contributor(s):
#  Atsushi Shimono <atsushi.shimono@ipmu.jp>

package PSMT::Attribute;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;

our $curtgt;

%PSMT::Attribute::EXPORT = qw(
    new

    SetTarget

    GetAttrForId
    AddAttrForId
    UpdateAttrForId

    ListExistKey
);

sub new {
    my ($self) = @_;
    $curtgt = 'attr_path'; # default to path
    return $self;
}

sub SetTarget {
    my ($self, $tgt) = @_;
    $tgt = lc($tgt);
    if ($tgt eq 'path') {$curtgt = 'attr_' . $tgt; return TRUE; }
    if ($tgt eq 'doc' ) {$curtgt = 'attr_' . $tgt; return TRUE; }
    if ($tgt eq 'file') {$curtgt = 'attr_' . $tgt; return TRUE; }
    return FALSE;
}

sub GetAttrForId {
    my ($self, $id) = @_;
    if (! defined($id)) {return undef; }
    my %attrs;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth = $dbh->prepare('SELECT key, value FROM ? WHERE id = ?');
    $sth->execute($curtgt, $id);
    my $ref;
    while ($ref = $sth->fetchrow_hashref())
      {$attrs{$ref->{key}} = $ref->{value}; }
    return \%attrs;
}

sub AddAttrForId {
    my ($self, $id, $key, $value) = @_;
    if (! defined($key)) {return FALSE; }
    # for value, if undef, insert null
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' WRITE');
    my $sth = $dbh->prepare('SELECT * FROM ? WHERE id = ? AND key = ?');
    $sth->execute($curtgt, $id, $key);
    if ($sth->rows() > 0) {return FALSE; }
    if (defined($value)) {
        $sth = $dbh->prepare('INSERT ? (id, key, value) VALUES (?, ?, ?)');
        if ($sth->execute($curtgt, $id, $key, $value) == 0) {return FALSE; }
    } else {
        $sth = $dbh->prepare('INSERT ? (id, key) VALUES (?, ?)');
        if ($sth->execute($curtgt, $id, $key) == 0) {return FALSE; }
    }
    return TRUE;
}

# if oldvalue or newvalue is '', consider as NULL
sub UpdateAttrForId {
    my ($self, $id, $key, $oldvalue, $newvalue) = @_;
    # if oldvalue is undefined, two values are undefined -> ERROR
    if (! defined($oldvalue)) {return FALSE; }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' WRITE');
    # First, check old value
    my $sth = $dbh->prepare('SELECT value FROM ? WHERE id = ? AND key = ?');
    $sth->execute($curtgt, $id, $key);
    if ($sth->rows != 1) {return FALSE; }
    my $ref = $sth->fetchrow_hashref();
    if ($oldvalue eq '') {if ($ref->{value} ne undef) {return FALSE; } } 
    else {if ($ref->{value} ne $oldvalue) {return FALSE; } }
    # Second, update value to new
    if (defined($newvalue)) {
        $sth = $dbh->prepare('UPDATE ? SET value = ? WHERE id ? AND key = ?');
        if ($sth->execute($curtgt, $newvalue, $id, $key) == 0) {return FALSE; }
    } else {
        $sth = $dbh->prepare('UPDATE ? SET value = NULL WHERE id ? AND key = ?');
        if ($sth->execute($curtgt, $id, $key) {return FALSE; }
    }
    return TRUE;
}

sub ListExistKey {
    my ($self, $id) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth;
    if (defined($id)) {
        $sth = $dbh->prepare('SELECT key FROM ? WHERE id = ? GROUP BY key');
        $sth->execute($curtgt, $id);
    } else {
        $sth = $dbh->prepare('SELECT key FROM ? GROUP BY key');
        $sth->execute($curtgt);
    }
    my (@ret, $ref);
    while ($ref = $sth->fetchrow_hashref()) {push(@ret, $ref->{key}); }
    return @ret;
}



1;

__END__


