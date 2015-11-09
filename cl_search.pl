#! /usr/bin/perl

use strict;

use PSMT;
use PSMT::FullSearchMroonga;

$ENV{'REMOTE_USER'} = 'shimono';

my $cond = $ARGV[0];
if (! defined($cond)) {
    print "Error: <cmd> cond\n";
    exit;
}

print "Open DB\n";
my $obj = new PSMT::FullSearchMroonga();
print "Opened\n";

print "Searching $cond\n";
my $res = $obj->ExecSearch($cond);

foreach (@$res) {
    print "$_\n";
}

exit;

