#! /usr/bin/perl

use strict;
use Digest::SHA;

use PSMT;
use PSMT::Constants;
use PSMT::File;

my $objSHA = new Digest::SHA->new(HASH_SIZE);

my $flist = PSMT::File->ListFileNoHash();

my ($buf, $chash);
foreach (@$flist) {
    $objSHA->reset(HASH_SIZE);
    open(INDAT, PSMT::File->GetFilePath($_) . $_);
    binmode INDAT;
    while (read(INDAT, $buf, 1024)) {$objSHA->add($buf); }
    $chash = $objSHA->b64digest;
    if (PSMT::File->AddFileHash($_, $chash) == FALSE) {
        print "Failed: $_\n";
    } else {
        print "Added: $_ = $chash\n";
    }
    close(INDAT);
}


exit;

