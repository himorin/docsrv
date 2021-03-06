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

my %cache_path;
my %cache_fpath;
my %cache_doc;

%PSMT::Access::EXPORT = qw(
    new

    CheckForPath
    CheckForDoc
    CheckForDocobj
    CheckForFile
    CheckSecureForFile

    CheckEditForFile

    ListFullPathRestrict
    ListPathRestrict
    ListPathsRestrict
    ListFullDocRestrict
    ListFullDocobjRestrict
    ListDocRestrict
    ListDocsRestrict

    SetPathAccessGroup
    SetDocAccessGroup
    ApplyDocAccessGroup
);

sub new {
    my ($self) = @_;
    return $self;
}

sub CheckForPath {
    my ($self, $pathid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    if ($pathid == 0) {return TRUE; }
    my $path_group = $self->ListFullPathRestrict($pathid);
    if ($self->_MatchGroupList($path_group) == TRUE) {return TRUE; }
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub CheckForDoc {
    my ($self, $docid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    my $doc_group = $self->ListFullDocRestrict($docid);
    if ($self->_MatchGroupList($doc_group) == TRUE) {return TRUE; }
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub CheckForDocobj {
    my ($self, $doc, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    my $doc_group = $self->ListFullDocobjRestrict($doc);
    if ($self->_MatchGroupList($doc_group) == TRUE) {return TRUE; }
    if ($is_throw) {PSMT::Error->throw_error_user('permission_error'); }
    return FALSE;
}

sub CheckSecureForFile {
    my ($self, $fileid) = @_;
    if (! defined($fileid)) {return FALSE; }
    my $finfo = PSMT::File->GetFileInfo($fileid);
    my $dinfo = PSMT::File->GetDocInfo($finfo->{docid});
    if ($dinfo->{secure} eq 1) {return TRUE; }
    return FALSE;
}

sub CheckForFile {
    my ($self, $fileid, $is_throw) = @_;
    if (! defined($is_throw)) {$is_throw = TRUE; }
    my $finfo = PSMT::File->GetFileInfo($fileid);
    if (! defined($finfo)) {return TRUE; }
    if ($finfo->{enabled} == 0) {
        # ok if uploader or is_inadmin
        if (($finfo->{uname} ne PSMT->user->get_uid()) &&
            (! PSMT->user->is_inadmin())) {
            PSMT::Error->throw_error_user('permission_error');
        }
    }
    return $self->CheckForDoc($finfo->{docid});
}

sub CheckEditForFile {
    my ($self, $fid, $is_throw) = @_;
    my $fileinfo = PSMT::File->GetFileInfo($fid);
    if (! defined($fileinfo)) {
        if (defined($is_throw)) {PSMT::Error->throw_error_user('invalid_fileid'); }
        else {return FALSE; }
    }
    if ((! PSMT->user->is_inadmin()) && 
        ($fileinfo->{uname} ne PSMT->user->get_uid())) {
        if (defined($is_throw)) {PSMT::Error->throw_error_user('permission_error'); }
        else {return FALSE; }
    }
    return TRUE;
}


sub ListFullPathRestrict {
    my ($self, $pathid) = @_;
    if (exists($cache_fpath{$pathid})) {return $cache_fpath{$pathid}; }
    my (@res, $cur, $cpid);
    $cur = $self->ListPathRestrict($pathid);
    @res = @$cur;
    $cpid = $pathid;
    while (($cpid = PSMT::File->GetPathIdForParent($cpid)) > 0) {
        @res = $self->_AndGroupList(\@res, $self->ListPathRestrict($cpid));
    }
    $cache_fpath{$pathid} = \@res;
    return \@res;
}

sub ListPathRestrict {
    my ($self, $pathid) = @_;
    if (exists($cache_path{$pathid})) {return $cache_path{$pathid}; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    $sth->execute($pathid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {push(@glist, $ref->{gname}); }
    $cache_path{$pathid} = \@glist;
    return \@glist;
}

sub ListPathsRestrict {
    my ($self, @pathid) = @_;
    my (@target);
    foreach (@pathid) {
        if (! exists($cache_path{$_})) {
            my @tmp = ();
            $cache_path{$_} = \@tmp;
            push(@target, $_);
        }
    }
    if ($#target < 0) {return \%cache_path; }
    my $dbh = PSMT->dbh;
    my $places = '(' . ('?,' x $#target) . '?)';
    my $sth = $dbh->prepare('SELECT * FROM access_path WHERE pathid IN ' . $places);
    $sth->execute(@target);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@{$cache_path{$ref->{pathid}}}, $ref->{gname});
    }
    return \%cache_path;
}

sub ListFullDocRestrict {
    my ($self, $docid) = @_;
    my (@glist, $doc, $path);
    $doc = $self->ListDocRestrict($docid);
    $path = $self->ListFullPathRestrict(PSMT::File->GetPathIdForDoc($docid));
    @glist = $self->_AndGroupList($doc, $path);
    return \@glist;
}

sub ListFullDocobjRestrict {
    my ($self, $doc) = @_;
    my (@glist, $path);
    if (! exists($doc->{gname})) {
        $doc->{gname} = $self->ListDocRestrict($doc->{docid});
    }
    $path = $self->ListFullPathRestrict($doc->{pathid});
    @glist = $self->_AndGroupList($doc->{gname}, $path);
    return \@glist;
}

sub ListDocRestrict {
    my ($self, $docid) = @_;
    if (exists($cache_doc{$docid})) {return $cache_doc{$docid}; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_doc WHERE docid = ?');
    $sth->execute($docid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {push(@glist, $ref->{gname}); }
    $cache_doc{$docid} = \@glist;
    return \@glist;
}

sub ListDocsRestrict {
    my ($self, @docid) = @_;
    my (@target);
    foreach (@docid) {
        if (! exists($cache_doc{$_})) {
            my @tmp = ();
            $cache_doc{$_} = \@tmp;
            push(@target, $_);
        }
    }
    if ($#target < 0) {return \%cache_doc; }
    my $dbh = PSMT->dbh;
    my $places = '(' . ('?,' x $#target) . '?)';
    my $sth = $dbh->prepare('SELECT * FROM access_doc WHERE docid IN ' . $places);
    $sth->execute(@target);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@{$cache_doc{$ref->{docid}}}, $ref->{gname});
    }
    return \%cache_doc;
}

sub SetPathAccessGroup {
    my ($self, $id, $group) = @_;
    return $self->_SetAccessGroup('path', $id, $group);
}

sub SetDocAccessGroup {
    my ($self, $id, $group) = @_;
    return $self->_SetAccessGroup('doc', $id, $group);
}

sub ApplyDocAccessGroup {
    my ($self, $id, $group, $is_and) = @_;
    if (! defined($is_and)) {$is_and = TRUE; }
    my $cgroup = $self->ListDocRestrict($id);
    if ($is_and) {
        my @newgroup = $self->_AndGroupList($group, $cgroup);
        return $self->SetDocAccessGroup($id, \@newgroup);
    }
    push(@$cgroup, @$group);
    return $self->SetDocAccessGroup($id, $cgroup);
}

################################################################## PRIVATE

sub _MatchGroupList {
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

sub _AndGroupList {
    my ($self, $a, $b) = @_;
    my @res;
    my @ga = @$a;
    my @gb = @$b;
    if ($#ga == -1) {return @gb; }
    if ($#gb == -1) {return @ga; }
    foreach $a (@ga) {
        foreach $b (@gb) {if ($a eq $b) {push(@res, $a); next; } }
    }
    if ($#res) {push(@res, PSMT::Config->GetParam('admingroup')); }
    return @res;
}

sub _SetAccessGroup {
    my ($self, $cat, $id, $group) = @_;
    my $dbh = PSMT->dbh;
    my %gconf;
    foreach (@{PSMT->ldap->GetAvailGroups}) {$gconf{$_} = 0; }
    # check group valid (via ldap)
    foreach (@$group) {$gconf{$_} = 1; }
    # start transaction, need commit after
    my $need_commit = $dbh->db_transaction_start(TRUE);
    # check current
    my $sth = $dbh->prepare('SELECT gname FROM access_' . $cat . ' WHERE ' . $cat . 'id = ?');
    my $ref;
    $sth->execute($id);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($gconf{$ref->{gname}})) {
            if ($gconf{$ref->{gname}} == 0) {$gconf{$ref->{gname}} = 2; }
            else {$gconf{$ref->{gname}} = 0; }
        }
    }
    # delete cache
    if ($cat eq 'path') {delete($cache_path{$id}); }
    elsif ($cat eq 'doc') {delete($cache_doc{$id}); }
    # update
    foreach (keys %gconf) {
        if ($gconf{$_} == 1) {
            $sth = $dbh->prepare('INSERT access_' . $cat . ' (' . $cat . 'id, gname) VALUES (?, ?)');
            $sth->execute($id, $_);
        } elsif ($gconf{$_} == 2) {
            $sth = $dbh->prepare('DELETE FROM access_' . $cat . ' WHERE ' . $cat . 'id = ? AND gname = ?');
            $sth->execute($id, $_);
        }
    }
    # commit transaction, no intermediate return
    if ($need_commit) {$dbh->db_transaction_commit(); }
    return TRUE;
}


1;

__END__


