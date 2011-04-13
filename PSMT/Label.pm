# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Label manipulation
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Label;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;

%PSMT::Label::EXPORT = qw(
    new

    ListAllLabel
    CreateLabel

    ListLabelOnDoc
    ModLabelOnDoc
    ListDocOnLabel
);

sub new {
    my ($self) = @_;
    return $self;
}

sub ListAllLabel {
    my ($self) = @_;
    my %labels;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM label');
    $sth->execute();
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {$labels{$ref->{labelid}} = $ref; }
    return \%labels;
}

sub ListLabelOnDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT labelid FROM label_doc WHERE docid = ?');
    $sth->execute($docid);
    my (@labels, $ref);
    while ($ref = $sth->fetchrow_hashref()) {push(@labels, $ref->{labelid}); }
    return \@labels;
}

sub CreateLabel {
    my ($self, $name, $description) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('label WRITE');
    my $sth = $dbh->prepare('INSERT label (name, description) VALUES (?, ?)');
    if ($sth->execute($name, $description) == 0) {return 0; }
    my $labelid = $dbh->db_last_key('label', 'labelid');
    $dbh->db_unlock_tables();
    return $labelid;
}

sub GetLabelLastId {
    my ($self) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT labelid FROM label ORDER BY labelid DESC LIMIT 1');
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    if (! defined($ref)) {return 0; }
    return $ref->{labelid};
}

sub ModLabelOnDoc {
    my ($self, $docid, $labelid) = @_;
    my $dbh = PSMT->dbh;
    my $last_id = $self->GetLabelLastId();
    my %labels;
    foreach (@$labelid) {$labels{$_} = 1; }
    my $sth = $dbh->prepare('SELECT labelid FROM label_doc WHERE docid = ?');
    my $ref;
    $sth->execute($docid);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($labels{$ref->{labelid}})) {$labels{$ref->{labelid}} = 0; }
        else {$labels{$ref->{labelid}} = 2; }
    }
    foreach (keys %labels) {
        if ($labels{$_} == 1) {
            $sth = $dbh->prepare('INSERT label_doc (labelid, docid) VALUES (?, ?)');
            $sth->execute($docid, $_);
        } elsif ($labels{$_} == 2) {
            $sth = $dbh->prepare('DELETE FROM label_doc WHERE labelid = ? AND docid = ?');
            $sth->execute($docid, $_);
        }
    }
    return TRUE;
}




1;

__END__

