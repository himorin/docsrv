# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - DB st interface
#
# License: GPL, MPL (dual)

package PSMT::DBst;

use strict;

use DBI;
use base qw(DBI::st);

use Time::HiRes qw( tv_interval gettimeofday );

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;

my $obj_db;

sub AddObjDB {
    my ($self, $obj) = @_;
    $obj_db = $obj;
}

sub execute {
    my ($self, @opts) = @_;
    my $ret;
    my $tst;
    $tst = [gettimeofday];
    my $tstd = $tst->[0] + $tst->[1] / 1000000;
    $ret = $self->SUPER::execute(@opts);
    my $ttv = tv_interval($tst);
    $obj_db->AddDebug("EXECUTE: elapse $ttv (from $tstd)");
    $obj_db->AddTimeExecute($ttv);
    return $ret;
}



################################################################## PRIVATE



1;

__END__



