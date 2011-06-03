#! /usr/bin/perl

use strict;

use PSMT;
use PSMT::Constants;
use PSMT::HyperEstraier;

$ENV{'REMOTE_USER'} = 'shimono';

if (! -d '/usr/share/poppler/cMap/Adobe-Japan1') {
    print "Warning, cannot found Adobe-Japan1 in your system.\n";
    print "Add cmap package, such as poppler-data in Debian\n";
    exit;
}

my $fid = $ARGV[0];
if (! defined($fid)) {
    print "Error: <cmd> fid\n";
    exit;
}

print "Open DB\n";
my $obj = new PSMT::HyperEstraier(TRUE);
print "Opened\n";

print "Adding $fid\n";
$obj->AddNewFile($fid);

exit;

