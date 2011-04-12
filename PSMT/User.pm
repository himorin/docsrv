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
    user_data

    is_ingroup
);

our %conf;
our $ldap_gid;
our $obj_ldap;

sub new {
    my ($self) = @_;
    $self->fetch_userdata();
    return $self;
}

sub get_uid {
    return $conf{'uid'};
}

sub user_data {
    return \%conf;
}

sub is_ingroup {
    my ($self, $gid) = @_;
    foreach (@$ldap_gid) {
        if ($_ eq $gid) {return TRUE; }
    }
    return FALSE;
}


################################################################## PRIVATE

sub fetch_userdata {
    my ($self);
    $conf{'uid'} = $ENV{'REMOTE_USER'};
    $obj_ldap = new PSMT::NetLdap;
    if (! $obj_ldap->bind) {
        PSMT::Error->throw_error_code('ldap_bind_anonymous');
    }
    $conf{'dn'} = $obj_ldap->GetDNFromUID($conf{'uid'});
    if (! defined($conf{'dn'})) {
        PSMT::Error->throw_error_user('ldap_uid_notfound');
    }
    $ldap_gid = $obj_ldap->SearchMemberGroups($conf{'uid'});
}

1;

__END__


