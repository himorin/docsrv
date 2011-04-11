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
);

our %conf;

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

sub fetch_userdata {
    my ($self);
}


################################################################## PRIVATE

1;

__END__


