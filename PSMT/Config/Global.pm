# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Config Definition - global
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Config::Global;

use strict;

use PSMT::Config::Common;

$PSMT::Config::Global::sortkey = "01";

sub get_param_list {
    my $class = shift;
    my @param_list = (
        {
            name     => 'base_uri',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'admin_email',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'view_mime',
            type     => 'text',
            default  => 'image',
        },
        {
            name     => 'email_lang',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'zip_win_encoding',
            type     => 'text',
            default  => 'cp932',
        },
        {
            name     => 'cl_user',
            type     => 'text',
            default  => '',
        },
    );
    return @param_list;
}

1;

__END__


