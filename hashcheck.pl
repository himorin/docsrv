#! /usr/bin/perl

use strict;
use Digest::SHA;

use PSMT;
use PSMT::Constants;
use PSMT::File;

my $objSHA = new Digest::SHA->new(HASH_SIZE);

my $flist = PSMT::File->ListFileNoHash();

my ($buf, $chash, $cmatch);
foreach (@$flist) {
    $objSHA->reset(HASH_SIZE);
    open(INDAT, PSMT::File->GetFilePath($_) . $_);
    binmode INDAT;
    while (read(INDAT, $buf, 1024)) {$objSHA->add($buf); }
    $chash = $objSHA->b64digest;
    if (defined($cmatch = PSMT::File->CheckFileHash($chash))) {
        print "$_ Matched with: \n";
        print join(@$cmatch, "\n");
    }
    if (PSMT::File->AddFileHash($_, $chash) == FALSE) {
        print "Hash Add Failed: $_\n";
    } else {
        print "Added: $_ = $chash\n";
    }
    close(INDAT);
}


exit;

