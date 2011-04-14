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

%PSMT::Config::EXPORT = qw(
    new

    get_uid
    get_gid
    user_data

    is_ingroup
    is_inadmin

    is_infav
    MakeFav
    RemoveFav
    ListFavs
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

sub is_inadmin {
    my ($self) = @_;
    return $self->is_ingroup(PSMT::Config->GetParam('admingroup'));
}

sub is_infav {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT docid FROM favorite WHERE docid = ? AND uname = ?');
    $sth->execute($docid, $conf{'uid'});
    if ($sth->rows() == 0) {return FALSE; }
    return TRUE;
}

sub MakeFav {
    my ($self, $docid) = @_;
    if ($self->is_infav($docid) == TRUE) {return ; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('INSERT INTO favorite (docid, uname) VALUES (?, ?)');
    $sth->execute($docid, $conf{'uid'});
}

sub RemoveFav {
    my ($self, $docid) = @_;
    if ($self->is_infav($docid) == FALSE) {return ; }
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('DELETE FROM favorite WHERE docid = ? AND uname = ?');
    $sth->execute($docid, $conf{'uid'});
}

sub ListFavs {
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
    $conf{'favs'} = $self->ListFavs();
}

1;

__END__


