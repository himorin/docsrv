# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - User authentication
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::User;

use strict;

use Digest::MD5;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::NetLdap;
use PSMT::CGI;

%PSMT::Config::EXPORT = qw(
    new

    get_uid
    get_gid
    user_data

    is_ingroup
    is_inadmin

    is_infav_doc
    MakeFavDoc
    RemoveFavDoc
    ListFavsDoc

    is_infav_path
    MakeFavPath
    RemoveFavPath
    ListFavsPath
);

our %conf;
our $obj_ldap;

sub new {
    my ($self) = @_;
    $self->fetch_userdata();
    return $self;
}

sub get_uid {
    return $conf{'uid'};
}

sub get_gid {
    return $conf{'gid'};
}

sub user_data {
    return \%conf;
}

sub is_ingroup {
    my ($self, $gid) = @_;
    foreach (@{$conf{'gid'}}) {
        if ($_ eq $gid) {return TRUE; }
    }
    return FALSE;
}

# ign_cookie : ignore cookie if TRUE
sub is_inadmin {
    my ($self, $ign_cookie) = @_;
    if (! $self->is_ingroup(PSMT::Config->GetParam('admingroup'))) {
        return FALSE;
    }
    # if ign_cookie is TRUE, ignore cookie and return TRUE
    if (defined($ign_cookie) && $ign_cookie) {return TRUE; }
    # by default, check cookie(admin) and return false if "disable"
    my $cookie_admin = PSMT->cgi()->cookie('admin');
    if (defined($cookie_admin) && ($cookie_admin eq 'disable')) {
        return FALSE;
    }
    return TRUE;
}

sub is_infav_doc {
    my ($self, $docid, $no_path) = @_;
    if (! defined($no_path)) {$no_path = FALSE; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT docid FROM favorite WHERE docid = ? AND uname = ?');
    $sth->execute($docid, $conf{'uid'});
    if ($sth->rows() > 0) {return TRUE; }
    if ($no_path == TRUE) {return FALSE; }
    return $self->is_infav_path(PSMT::File->GetPathIdForDoc($docid));
}

sub is_infav_path {
    my ($self, $pid, $no_rec) = @_;
    if (! defined($no_rec)) {$no_rec = FALSE; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT pathid FROM fav_path WHERE pathid = ? AND uname = ?');
    while ($pid != 0) {
        $sth->execute($pid, $conf{'uid'});
        if ($sth->rows() > 0) {return TRUE; }
        if ($no_rec == TRUE) {$pid = 0; }
        else {$pid = PSMT::File->GetPathIdForParent($pid); }
    }
    return FALSE;
}

sub MakeFavDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_transaction_start();
    if ($self->is_infav_doc($docid, TRUE) == TRUE) {
        $dbh->db_transaction_rollback();
        return ;
    }
    my $sth = $dbh->prepare('INSERT INTO favorite (docid, uname) VALUES (?, ?)');
    $sth->execute($docid, $conf{'uid'});
    $dbh->db_transaction_commit();
}

sub RemoveFavDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_transaction_start();
    if ($self->is_infav_doc($docid, TRUE) == FALSE) {
        $dbh->db_transaction_rollback();
        return ;
    }
    my $sth = $dbh->prepare('DELETE FROM favorite WHERE docid = ? AND uname = ?');
    $sth->execute($docid, $conf{'uid'});
    $dbh->db_transaction_commit();
}

sub ListFavsDoc {
    my ($self) = @_;
    my @docs;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT docid FROM favorite WHERE uname = ?');
    $sth->execute($conf{'uid'});
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@docs, $ref->{docid});
    }
    return \@docs;
}

sub MakeFavPath {
    my ($self, $pid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_transaction_start();
    if ($self->is_infav_path($pid, TRUE) == TRUE) {
        $dbh->db_transaction_rollback();
        return ;
    }
    my $sth = $dbh->prepare('INSERT INTO fav_path (pathid, uname) VALUES (?, ?)');
    $sth->execute($pid, $conf{'uid'});
    $dbh->db_transaction_commit();
}

sub RemoveFavPath {
    my ($self, $pid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_transaction_start();
    if ($self->is_infav_path($pid, TRUE) == FALSE) {
        $dbh->db_transaction_rollback();
        return ;
    }
    my $sth = $dbh->prepare('DELETE FROM fav_path WHERE pathid = ? AND uname = ?');
    $sth->execute($pid, $conf{'uid'});
    $dbh->db_transaction_commit();
}

sub ListFavsPath {
    my ($self) = @_;
    my @path;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT pathid FROM fav_path WHERE uname = ?');
    $sth->execute($conf{'uid'});
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@path, $ref->{pathid});
    }
    return \@path;
}

################################################################## PRIVATE

sub fetch_userdata {
    my ($self) = @_;
    $conf{'uid'} = $ENV{'REMOTE_USER'};
    $obj_ldap = PSMT->ldap();
    if (! defined($obj_ldap)) {
        PSMT::Error->throw_error_code('ldap_connect');
    }
    if (! $obj_ldap->bind) {
        PSMT::Error->throw_error_code('ldap_bind_anonymous');
    }
    $conf{'dn'} = $obj_ldap->GetDNFromUID($conf{'uid'});
    if (! defined($conf{'dn'})) {
        PSMT::Error->throw_error_user('ldap_uid_notfound');
    }
    $conf{'gid'} = $obj_ldap->SearchMemberGroups($conf{'uid'});
    $conf{'favs'} = $self->ListFavsDoc();
    $conf{'favs_path'} = $self->ListFavsPath();
}

1;

__END__


