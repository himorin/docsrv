# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Access restriction manipulation
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Access;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::User;
use PSMT::Util;
use PSMT::Error;
use PSMT::File;

%PSMT::Access::EXPORT = qw(
    new

    CheckForPath
    CheckForDoc
    CheckForFile
    MatchGroupList

    ListPathRestrict
    ListDocRestrict
    ListLabelRestrict

    SetPathAccessGroup
    ModLabelRestrict
);

sub new {
    my ($self) = @_;
    return $self;
}

sub CheckForPath {
    my ($self, $pathid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    if ($pathid == 0) {return TRUE; }
    # check for path
    my $path_group = $self->ListPathRestrict($pathid);
    if ($self->MatchGroupList($path_group) == TRUE) {return TRUE; }
    # raise error
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub CheckForDoc {
    my ($self, $docid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    # check for path, label
    my $path_group = $self->ListDocRestrict($docid);
    my $labels = PSMT::Label->ListLabelOnDoc($docid);
    my $label_group = $self->ListLabelRestrict(@$labels);
    if (($self->MatchGroupList($path_group) == TRUE) &&
        ($self->MatchGroupList($label_group) == TRUE))
        {return TRUE; }
    # raise error
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub CheckForFile {
    my ($self, $fileid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    my $finfo = PSMT::File->GetFileInfo($fileid);
    if (! defined($finfo)) {return TRUE; }
    # check for path, label
    my $path_group = $self->ListDocRestrict($finfo->{docid});
    my $labels = PSMT::Label->ListLabelOnDoc($finfo->{docid});
    my $label_group = $self->ListLabelRestrict(@$labels);
    if (($self->MatchGroupList($path_group) == TRUE) &&
        ($self->MatchGroupList($label_group) == TRUE))
        {return TRUE; }
    # raise error
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub ListDocRestrict {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT access_path.gname AS gname FROM access_path LEFT JOIN docreg ON access_path.pathid = docreg.pathid WHERE docreg.docid = ?');
    $sth->execute($docid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {push(@glist, $ref->{gname}); }
    return \@glist;
}

sub ListPathRestrict {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    $sth->execute($pathid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {push(@glist, $ref->{gname}); }
    return \@glist;
}

sub SetPathAccessGroup {
    my ($self, $pathid, $group) = @_;
    my $dbh = PSMT->dbh;
    my %gconf;
    foreach (@{PSMT->ldap->GetAvailGroups}) {$gconf{$_} = 0; }
    # check group valid (via ldap)
    foreach (@$group) {$gconf{$_} = 1; }
    # check current
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    my $ref;
    $sth->execute($pathid);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($gconf{$ref->{gname}})) {
            if ($gconf{$ref->{gname}} == 0) {$gconf{$ref->{gname}} = 2; }
            else {$gconf{$ref->{gname}} = 0; }
        }
    }
    # update
    foreach (keys %gconf) {
        if ($gconf{$_} == 1) {
            $sth = $dbh->prepare('INSERT access_path (pathid, gname) VALUES (?, ?)');
            $sth->execute($pathid, $_);
        } elsif ($gconf{$_} == 2) {
            $sth = $dbh->prepare('DELETE FROM access_path WHERE pathid = ? AND gname = ?');
            $sth->execute($pathid, $_);
        }
    }
    return TRUE;
}

sub MatchGroupList {
    my ($self, $list) = @_;
    my @target = @$list;
    # if list size contains no group, always OK
    if ($#target == -1) {return TRUE; }
    foreach (@target) {
        # if is in group, OK
        if (PSMT->user()->is_ingroup($_) == TRUE) {return TRUE; }
    }
    # if not match with any group, NG!
    return FALSE;
}

sub ModLabelRestrict {
    my ($self, $labelid, $group) = @_;
    my $dbh = PSMT->dbh;
    my %gconf;
    foreach (@{PSMT->ldap->GetAvailGroups}) {$gconf{$_} = 0; }
    # check group valid (via ldap)
    foreach (@$group) {$gconf{$_} = 1; }
    # check current
    my $sth = $dbh->prepare('SELECT gname FROM access_label WHERE labelid = ?');
    my $ref;
    $sth->execute($labelid);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($gconf{$ref->{gname}})) {
            if ($gconf{$ref->{gname}} == 0) {$gconf{$ref->{gname}} = 2; }
            else {$gconf{$ref->{gname}} = 0; }
        }
    }
    # update
    foreach (keys %gconf) {
        if ($gconf{$_} == 1) {
            $sth = $dbh->prepare('INSERT access_label (labelid, gname) VALUES (?, ?)');
            $sth->execute($labelid, $_);
        } elsif ($gconf{$_} == 2) {
            $sth = $dbh->prepare('DELETE FROM access_label WHERE labelid = ? AND gname = ?');
            $sth->execute($labelid, $_);
        }
    }
    return TRUE;
}

sub ListLabelRestrict {
    my ($self, @labelid) = @_;
    my @gname;
    if ($#labelid == -1) {return \@gname; }
    my $dbh = PSMT->dbh;
    my $str_sth = 'SELECT gname FROM access_label WHERE labelid = ?';
    foreach (1 .. $#labelid) {$str_sth .= ' OR labelid = ?'; }
    my $sth = $dbh->prepare($str_sth);
    $sth->execute(@labelid);
    if ($sth->rows() == 0) {return \@gname; }
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@gname, $ref->{gname}); }
    return \@gname;
}



################################################################## PRIVATE


1;

__END__


