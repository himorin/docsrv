# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Config Definition - DB
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Config::DB;

use strict;

use PSMT::Config::Common;

$PSMT::Config::DB::sortkey = "01";

sub get_param_list {
    my $class = shift;
    my @param_list = (
        {
            name     => 'db_driver',
            type     => 'select',
            choices  => [ 'mysql' ],
            default  => 'mysql',
        },
        {
            name     => 'db_host',
            type     => 'text',
            default  => 'localhost',
        },
        {
            name     => 'db_name',
            type     => 'text',
            default  => 'forum',
        },
        {
            name     => 'db_port',
            type     => 'number',
            default  => 0,
        },
        {
            name     => 'db_sock',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'db_user',
            type     => 'text',
            default  => 'forum',
        },
        {
            name     => 'db_pass',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'db_err_maxlen',
            type     => 'number',
            default  => 4000,
        },
    );
    return @param_list;
}

1;

__END__




