# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Net::LDAP wrapper routines.
#
# Copyright (C) 2008 - 2009 Nano-opt

package PSMT::NetLdap;

use strict;
use Net::LDAP;

use PSMT::Constants;
use PSMT::Config;

use base qw(Exporter);
%PSMT::NetLdap::EXPORT = qw(
    new
    bind

    GetAvailGroups
    GetHashAvailGroups

    SearchUID
    SearchMemberGroups
    GetDNFromUID
    GetAttrsFromUID

    Entry_AddAttr
    Entry_ReplaceAttr
    Entry_DelAttr
);

my ($obj_ldap, $ldap_bind);

sub new {
    my ($self) = @_;

    $obj_ldap = Net::LDAP->new(PSMT::Config->GetParam('ldap_uri'))
        or return undef;
    $ldap_bind = FALSE;

    return $self;
}

sub bind {
    my ($self, $dn, $opt) = @_;
    my $msg;
    if ($ldap_bind) {
        $obj_ldap->unbind;
    }
    if (defined($dn)) {
        $msg = $obj_ldap->bind($dn, %$opt);
    } else {
        $msg = $obj_ldap->bind;
    }
    if (! $msg->code) {
        $ldap_bind = TRUE;
    }
    return $ldap_bind;
}

sub SearchUID {
    my ($self, $uid, @attrs) = @_;
    if (! $ldap_bind) {return undef; }
    my %ldap_attr;
    $ldap_attr{base} = PSMT::Config->GetParam('ldap_basedn');
    $ldap_attr{filter} = "(uid=$uid)";
    $ldap_attr{scope} = "sub";
    if ($#attrs > -1) {
        push(@attrs);
        $ldap_attr{attrs} = \@attrs;
    }
    my $ldap_res = $obj_ldap->search(%ldap_attr);
    return $ldap_res->entries;
}

sub SearchMemberGroups {
    my ($self, $uid) = @_;
    if (! $ldap_bind) {return undef; }
    if (! defined($uid)) {return undef; }
    my @groups;
    my %ldap_attr;
    $ldap_attr{base} = PSMT::Config->GetParam('ldap_basedn');
    $ldap_attr{filter} = "(memberUid=$uid)";
    $ldap_attr{scope} = "sub";
    my $ldap_res = $obj_ldap->search(%ldap_attr);
    if ($ldap_res->code != 0) {return undef; }
    foreach ($ldap_res->entries) {
        push(@groups, $_->get_value('cn'));
    }
    return \@groups;
}

sub Entry_AddAttr {
    my ($self, $target, $name, $value) = @_;
    return $obj_ldap->modify($target, add => {$name => $value} );
}

sub Entry_ReplaceAttr {
    my ($self, $target, $name, $value) = @_;
    return $obj_ldap->modify($target, replace => {$name => $value} );
}

sub Entry_DelAttr {
    my ($self, $target, $name, $value) = @_;
    return $obj_ldap->modify($target, delete => {$name => $value} );
}

sub GetDNFromUID {
    my ($self, $uid) = @_;
    my @entries = $self->SearchUID($uid);
    if ($#entries != 0) {
        return undef;
    }
    return $entries[0]->dn;
}

sub GetAttrsFromUID {
    my ($self, $uid, @attr) = @_;
    my %ret;
    my @entries = $self->SearchUID($uid, @attr);
    if ($#entries == 0) {
        my $entry = $entries[0];
        foreach (@attr) {
            if ($entry->exists($_)) {
                $ret{$_} = $entry->get_value($_, asref => 1);
            }
        }
    }
    return \%ret;
}

sub GetAvailGroups {
    my ($self) = @_;
    if (! $ldap_bind) {return undef; }
    my @groups;
    my %ldap_attr;
    $ldap_attr{base} = PSMT::Config->GetParam('ldap_basedn');
    $ldap_attr{filter} = "(objectClass=posixGroup)";
    $ldap_attr{scope} = "sub";
    my $ldap_res = $obj_ldap->search(%ldap_attr);
    if ($ldap_res->code != 0) {return undef; }
    foreach ($ldap_res->entries) {
        push(@groups, $_->get_value('cn'));
    }
    return \@groups;
}

sub GetHashAvailGroups {
    my ($self, $exist) = @_;
    my %hash;
    my $arr = $self->GetAvailGroups();
    foreach (@$arr) {$hash{$_} = 0; }
    foreach (@$exist) {$hash{$_} = 1; }
    return \%hash;
}


1;

