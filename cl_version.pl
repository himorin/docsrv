#! /usr/bin/perl

use strict;
use lib '.';

use PSMT;
use PSMT::File;
use PSMT::Config;
use PSMT::Constants;

$ENV{'REMOTE_USER'} = PSMT->config()->GetParam('cl_user');

# Check version in docinfo, modify if any has 0.0

my $doc_count = PSMT::File->GetAllDocCount();

my ($did, $flist, $cver);
for (1 ... $doc_count) {
    $did = $_;
    print "Doc: $did\n";
    $flist = PSMT::File->ListFilesInDoc($did, TRUE);
    if ($#$flist == -1) {next; }
    elsif ($#$flist == 0) {
        PSMT::File->UpdateFileVersion($flist->[0]->{fileid}, 1.0);
        next;
    }
    # ListFilesInDoc sorts by "version DESC, uptime DESC", so @$flist shall 
    # be already sorted by uptime from the newest.
    # NOT consider when version is assigned to some file.
    $cver = $#$flist + 1.0;
    foreach (@$flist) {
        PSMT::File->UpdateFileVersion($_->{fileid}, $cver);
        $cver -= 1.0;
    }
}

exit;


