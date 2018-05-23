#! /usr/bin/perl

use strict;
use lib '.';
use PSMT;

PSMT->config()->update_file();
my $conf = PSMT->config()->GetHash();

foreach (sort keys %$conf) {
    print "$_ : $conf->{$_}\n";
}


exit;

