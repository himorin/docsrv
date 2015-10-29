#! /usr/bin/perl

use strict;
use PSMT;

use PSMT::Constants;
use PSMT::Template;
use PSMT::Config;
use PSMT::CGI;
use PSMT::DB;
use PSMT::User;
use PSMT::Util;
use PSMT::File;
use PSMT::Access;
use PSMT::Email;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Encode;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $pid = $obj_cgi->param('pid');
if (! defined($pid)) {PSMT::Error->throw_error_user('invalid_pathid'); }
my $pext = $obj_cgi->param('ext');

my @lpid;
push(@lpid, $pid);

# start zip object
my $obj_zip = Archive::Zip->new();

# seek @lpid, add found child to end of @lpid
my ($cpid, $cpo, $cdo, $cfo, $cname, $zname, $cfid, $ch, $cext, @acext, $chid);
if ((! defined($pext)) || ($pext ne 'ALL')) {push (@acext, $pext); }
while ($#lpid > -1) {
    $cpid = shift(@lpid);
    # per path: check group restriction, add to zip
    #           push every subpath into @lpid, seek docs in $cpid
    if ($cpid != 0) {
        $cpo = PSMT::File->GetPathInfo($cpid);
        if (! defined($cpo)) {next; }
        if (! PSMT::Access->CheckForPath($cpid, FALSE)) {next; }
        $obj_zip->addDirectory(PSMT::File->GetFullPathFromId($cpid));
    }
    $ch = PSMT::File->ListPathIdInPath($cpid);
    push(@lpid, @$ch);
    $ch = PSMT::File->ListDocsInPath($cpid);
    foreach (@$ch) {
        $chid = $_;
        if (defined($pext) && ($pext eq 'ALL')) {
            $cext = PSMT::File->ListExtInDoc($chid->{docid});
            @acext = (@$cext);
        }
        foreach (@acext) {
            # per doc: get last fid, check security flag, check group restriction
            #          get full path + ext, get storage path
            $cfid = PSMT::File->GetDocLastPostFileId($chid->{docid}, $_);
            if (! defined($cfid)) {next; }
            if (! PSMT::Access->CheckForFile($cfid, FALSE)) {next; }
            if (PSMT::Access->CheckSecureForFile($cfid)) {next; }
            $cfo = PSMT::File->GetFileInfo($cfid);

            my $cname = PSMT::File->GetFilePath($cfid) . $cfid;
            if (! -f $cname) {next; }

            $zname = PSMT::File->GetFileFullPath($cfid);
    #        $zname = encode('Shift_JIS', decode('UTF-8', $zname));
            PSMT::File->RegUserAccess($cfid);
            $obj_zip->addFile($cname, $zname);
        }
    }
}

my $dname = PSMT::File->GetFullPathFromId($pid);
if ($dname eq '') {$dname = 'topdir'; }
$dname =~ s/\//_/g;
# output to client, just name $pid.zip
binmode STDOUT, ':bytes';
print $obj_cgi->header(
    -type => PSMT::File->GetFileExt("zip") . "; name=\"$dname.zip\"",
    -content_disposition => "attachment; filename=\"$dname.zip\"",
);
$obj_zip->writeToFileHandle(*STDOUT);

exit;

