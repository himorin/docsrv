# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Config Definition - File
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Config::File;

use strict;

use PSMT::Config::Common;

$PSMT::Config::File::sortkey = "01";

sub get_param_list {
    my $class = shift;
    my @param_list = (
        {
            name     => 'file_path',
            type     => 'text',
            default  => '',
        },
        {
            name     => 'hash_depth',
            type     => 'number',
            default  => 2,
        },
    );
    return @param_list;
}

1;

__END__


