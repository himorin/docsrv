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

    GetIdForAttr
    GetIdForValue
    GetIdForPair
    GetValueForAttr

    ListExistAttr
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
    my $sth = $dbh->prepare('SELECT attr, value FROM ' . $curtgt . ' WHERE id = ?');
    $sth->execute($id);
    my $ref;
    while ($ref = $sth->fetchrow_hashref())
      {$attrs{$ref->{attr}} = $ref->{value}; }
    return \%attrs;
}

sub GetIdForAttr {
    my ($self, $attr) = @_;
    if (! defined($attr)) {return undef; }
    my @ids;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth = $dbh->prepare('SELECT id FROM ' . $curtgt . ' WHERE attr = ? GROUP BY id');
    $sth->execute($attr);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@ids, $ref->{id}); }
    return \@ids;
}

sub GetIdForValue {
    my ($self, $value) = @_;
    if (! defined($value)) {return undef; }
    my @ids;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth = $dbh->prepare('SELECT id FROM ' . $curtgt . ' WHERE value = ? GROUP BY id');
    $sth->execute($value);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@ids, $ref->{id}); }
    return \@ids;
}

sub GetIdForPair {
    my ($self, $attr, $value) = @_;
    if (! defined($attr)) {return undef; }
    my @ids;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth;
    if (defined($value)) {
      $sth = $dbh->prepare('SELECT id FROM ' . $curtgt . ' WHERE attr = ? AND value = ? GROUP BY id');
      $sth->execute($attr, $value);
    } else {
      $sth = $dbh->prepare('SELECT id FROM ' . $curtgt . ' WHERE attr = ? AND value = NULL GROUP BY id');
      $sth->execute($attr);
    }
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@ids, $ref->{id}); }
    return \@ids;
}

sub GetValueForAttr {
    my ($self, $attr) = @_;
    if (! defined($attr)) {return undef; }
    my @values;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth = $dbh->prepare('SELECT value FROM ' . $curtgt . ' WHERE attr = ? GROUP BY value');
    $sth->execute($attr);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@values, $ref->{value}); }
    return \@values;
}

sub AddAttrForId {
    my ($self, $id, $attr, $value) = @_;
    if (! defined($attr)) {return FALSE; }
    # for value, if undef, insert null
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' WRITE');
    my $sth = $dbh->prepare('SELECT * FROM ' . $curtgt . ' WHERE id = ? AND attr = ?');
    $sth->execute($id, $attr);
    if ($sth->rows() > 0) {return FALSE; }
    if (defined($value)) {
        $sth = $dbh->prepare('INSERT ' . $curtgt . ' (id, attr, value) VALUES (?, ?, ?)');
        if ($sth->execute($id, $attr, $value) == 0) {return FALSE; }
    } else {
        $sth = $dbh->prepare('INSERT ' . $curtgt . ' (id, attr) VALUES (?, ?)');
        if ($sth->execute($id, $attr) == 0) {return FALSE; }
    }
    return TRUE;
}

# if oldvalue or newvalue is '', consider as NULL
sub UpdateAttrForId {
    my ($self, $id, $attr, $oldvalue, $newvalue) = @_;
    # if oldvalue is undefined, two values are undefined -> ERROR
    if (! defined($oldvalue)) {return FALSE; }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' WRITE');
    # First, check old value
    my $sth = $dbh->prepare('SELECT value FROM ' . $curtgt . ' WHERE id = ? AND attr = ?');
    $sth->execute($id, $attr);
    if ($sth->rows != 1) {return FALSE; }
    my $ref = $sth->fetchrow_hashref();
    if ($oldvalue eq '') {if ($ref->{value} ne undef) {return FALSE; } } 
    else {if ($ref->{value} ne $oldvalue) {return FALSE; } }
    # Second, update value to new
    if (defined($newvalue)) {
        $sth = $dbh->prepare('UPDATE ' . $curtgt . ' SET value = ? WHERE id = ? AND attr = ?');
        if ($sth->execute($newvalue, $id, $attr) == 0) {return FALSE; }
    } else {
        $sth = $dbh->prepare('UPDATE ' . $curtgt . ' SET value = NULL WHERE id = ? AND attr = ?');
        if ($sth->execute($id, $attr) == 0) {return FALSE; }
    }
    return TRUE;
}

sub ListExistAttr {
    my ($self, $id) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables($curtgt . ' READ');
    my $sth;
    if (defined($id)) {
        $sth = $dbh->prepare('SELECT attr FROM ' . $curtgt . ' WHERE id = ? GROUP BY attr');
        $sth->execute($id);
    } else {
        $sth = $dbh->prepare('SELECT attr FROM ' . $curtgt . ' GROUP BY attr');
        $sth->execute();
    }
    my (@ret, $ref);
    while ($ref = $sth->fetchrow_hashref()) {push(@ret, $ref->{attr}); }
    return @ret;
}



1;

__END__


