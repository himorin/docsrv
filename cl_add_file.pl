#! /usr/bin/perl

use strict;

use PSMT;
use PSMT::Config;
use PSMT::Constants;
use PSMT::FullSearchMroonga;

$ENV{'REMOTE_USER'} = PSMT::Config->GetParam('cl_user');

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
my $obj = new PSMT::FullSearchMroonga(TRUE);
print "Opened\n";

print "Adding $fid\n";
$obj->AddNewFile($fid);

exit;

