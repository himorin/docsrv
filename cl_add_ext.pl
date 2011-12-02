#! /usr/bin/perl

use strict;

use PSMT;
use PSMT::File;
use PSMT::Constants;
use PSMT::HyperEstraier;

$ENV{'REMOTE_USER'} = 'atsushi.shimono';

if (! -d '/usr/share/poppler/cMap/Adobe-Japan1') {
    print "Warning, cannot found Adobe-Japan1 in your system.\n";
    print "Add cmap package, such as poppler-data in Debian\n";
    exit;
}

my $ext = $ARGV[0];
if (! defined($ext)) {
    print "usage: <script> <file_ext>\n";
    exit;
}

print "Open DB\n";
my $obj_he = new PSMT::HyperEstraier(TRUE);
print "Opened\n";

my $obj_file = new PSMT::File;
my $arr_fids = $obj_file->ListFileInExt($ext);
foreach (@$arr_fids) {
    print "Adding $fid\n";
    $obj_he->AddNewFile($fid);

}

exit;

