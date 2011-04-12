#! /usr/bin/perl

use PSMT;

use strict;


PSMT->config()->update_file();
my $conf = PSMT->config()->GetHash();

foreach (sort keys %$conf) {
    print "$_ : $conf->{$_}\n";
}


exit;

