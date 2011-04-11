# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Config Definition - LDAP
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Config::Ldap;

use strict;

use PSMT::Config::Common;

$PSMT::Config::Ldap::sortkey = "01";

sub get_param_list {
    my $class = shift;
    my @param_list = (
        {
            name     => 'ldap_uri',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'ldap_basedn',
            type     => 'text',
            default  => '',
        },
    );
    return @param_list;
}

1;

__END__


