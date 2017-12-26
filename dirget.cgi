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
use PSMT::Archive;

#### options
# pid : path ID to download (all below this ID will be included)
# ext : extension to download (e.g. 'pdf', 'docx'), default to 'NEW'
#       'ALL' is all extension
#       'NEW' is newest but no filter with extension
# mode : 'last' for last uploaded, 'all' for all, default to 'last'
#
# WARN: ext='NEW'&mode='ALL' is invalid

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $pid = $obj_cgi->param('pid');
if (! defined($pid)) {PSMT::Error->throw_error_user('invalid_pathid'); }
my $pext = $obj_cgi->param('ext');
my $pmode = $obj_cgi->param('mode');

# check "ext='NEW'&mode='ALL'"
if (! defined($pext)) {$pext = 'NEW'; }
if (! defined($pmode)) {$pmode = 'last'; } else {$pmode = lc($pmode); }
if (($pext eq 'NEW') && ($pmode eq 'all')) {
    PSMT::Error->throw_error_user('invalid_param');
}

my @lpid;
push(@lpid, $pid);
my (@zip_path, $zip_sec, %zip_files);
$zip_sec = FALSE;

# seek @lpid, add found child to end of @lpid
my ($cpid, $cpo, $cdo, $clid, $cfid, $ch, $cext, @acext, $chid);
if ((! defined($pext)) || ($pext ne 'ALL')) {push (@acext, $pext); }
while ($#lpid > -1) {
    $cpid = shift(@lpid);
    # per path: check group restriction, add to zip
    #           push every subpath into @lpid, seek docs in $cpid
    if ($cpid != 0) {
        $cpo = PSMT::File->GetPathInfo($cpid);
        if (! defined($cpo)) {next; }
        if (! PSMT::Access->CheckForPath($cpid, FALSE)) {next; }
        push(@zip_path, PSMT::File->GetFullPathFromId($cpid));
    }
    $ch = PSMT::File->ListPathIdInPath($cpid);
    push(@lpid, @$ch);
    $ch = PSMT::File->ListDocsInPath($cpid);
    foreach (@$ch) {
        # per doc: get last fid, check security flag, check group restriction
        #          get full path + ext, get storage path
        $chid = $_;
        # first, last uploaded file mode
        if ($pmode ne 'all') {
            if ($pext eq 'ALL') {
                foreach (@{PSMT::File->ListExtInDoc($chid->{docid})}) {
                    $clid = PSMT::File->GetDocLastPostFile($chid->{docid}, $_)->{fileid};
                    if (&AddFileToZipEntry(\%zip_files, $clid)) {$zip_sec = TRUE; }
                }
            } elsif ($pext eq 'NEW') {
                if (&AddFileToZipEntry(\%zip_files, $chid->{lastfile}->{fileid})) {$zip_sec = TRUE; }
            } else {
                $clid = PSMT::File->GetDocLastPostFile($chid->{docid}, $pext)->{fileid};
                if (&AddFileToZipEntry(\%zip_files, $clid)) {$zip_sec = TRUE; }
            }
            next;
        }
        # second, ALL mode
        my ($docfiles, %lastfiles, $zip_fadd);
        if ($pext eq 'ALL') {
            $docfiles = PSMT::File->ListFilesInDoc($chid->{docid});
        } else {
            $docfiles = PSMT::File->ListFilesInDocByExt($chid->{docid}, $pext);
        }
        if ($#$docfiles < 0) {next; }
        foreach (@{PSMT::File->ListExtInDoc($chid->{docid})}) {
            $lastfiles{PSMT::File->GetDocLastPostFile($chid->{docid}, $_)->{fileid}}
                = $_;
        }
        foreach (@$docfiles) {
            if (defined($lastfiles{$_->{fileid}})) {
                # this is last file in doc for a ext
                $zip_fadd = undef;
            } else {
                $zip_fadd = &DateStrMod($_->{uptime}) . '-' . $_->{fileid};
            }
            if (&AddFileToZipEntry(\%zip_files, $_->{fileid}, $zip_fadd)) {$zip_sec = TRUE; }
        }
    }
}

my $dname = PSMT::File->GetFullPathFromId($pid);
if ($dname eq '') {$dname = 'topdir'; }
$dname =~ s/\/$//g;
$dname =~ s/\//_/g;
my $head = $obj_cgi->header(
    -type => PSMT::File->GetFileExt("zip") . "; name=\"$dname.zip\"",
    -content_disposition => "attachment; filename=\"$dname.zip\"",
);
binmode STDOUT, ':bytes';
if ($zip_sec) {
    PSMT::Archive->MakeEncrypted(\%zip_files, $head, $dname);
    exit;
}
PSMT::Archive->MakeNormal(\@zip_path, \%zip_files, $head);

exit;

sub DateStrMod {
    my ($source) = @_;
    $source =~ s/[\- :]//g;
    return $source;
}

# retrun values:
#   undef: processing error, file was not added to entry
#   TRUE: only if specified file is secure file
#   FALSE: normally finished
sub AddFileToZipEntry {
    my ($hash, $cfid, $postfix) = @_;
    my ($cname, $zname, $ret);
    $ret = FALSE;
    if (! defined($cfid)) {return undef; }
    if (! PSMT::Access->CheckForFile($cfid, FALSE)) {return undef; }
    if (PSMT::Access->CheckSecureForFile($cfid)) {$ret = TRUE; }
    my $cname = PSMT::File->GetFilePath($cfid) . $cfid;
    if (! -f $cname) {return undef; }
    $zname = PSMT::File->GetFileFullPath($cfid);
    if (defined($postfix)) {
        my $extidx = rindex($zname, '.');
        $zname = substr($zname, 0, $extidx) . '_' . $postfix . substr($zname, $extidx);
    }
    if (defined($hash->{$cname})) {return undef; }
    PSMT::File->RegUserAccess($cfid);
    $hash->{$cname} = $zname;
    return $ret;
}

