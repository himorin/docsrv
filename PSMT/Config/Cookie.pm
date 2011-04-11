# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Config Definition - cookie
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Config::Cookie;

use strict;

use PSMT::Config::Common;

$PSMT::Config::Cookie::sortkey = "01";

sub get_param_list {
    my $class = shift;
    my @param_list = (
        {
            name     => 'cookie_path',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'cookie_domain',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'cookie_expires',
            type     => 'text',
            default  => '+1m',
        },
    );
    return @param_list;
}

1;

__END__


