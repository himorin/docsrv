#! /usr/bin/perl

use strict;

use PSMT;
use PSMT::FullSearchHE;

$ENV{'REMOTE_USER'} = 'shimono';

my $cond = $ARGV[0];
if (! defined($cond)) {
    print "Error: <cmd> cond\n";
    exit;
}

print "Open DB\n";
my $obj = new PSMT::FullSearchHE();
print "Opened\n";

print "Searching $cond\n";
my $res = $obj->ExecSearch($cond);

foreach (@$res) {
    print "$_\n";
}

exit;

