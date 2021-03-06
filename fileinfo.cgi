#! /usr/bin/perl

use strict;
use lib '.';
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

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $fid = $obj_cgi->param('fid');
if (! defined($fid)) {PSMT::Error->throw_error_user('invalid_fileid'); }
my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }

my $method = $obj_cgi->param('method');
if ($obj_cgi->request_method() eq 'POST') {
    my $desc = $obj_cgi->param('description');
    my $version = $obj_cgi->param('version');
    PSMT::Access->CheckEditForFile($fid, TRUE);
    if (defined($desc)) {PSMT::File->UpdateFileDesc($fid, $desc); }
    if (defined($version)) {PSMT::File->UpdateFileVersion($fid, $version); }
} elsif (defined($method)) {
    # user who can disable file, can access file even if disabled
    PSMT::Access->CheckEditForFile($fid, TRUE);
    if ($method eq 'disable') {
        PSMT::File->EditFileAccess($fid, FALSE);
    } elsif ($method eq 'enable') {
        PSMT::File->EditFileAccess($fid, TRUE);
    }
}

# check permission
PSMT::Access->CheckForFile($fid);

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('file_info', PSMT::File->GetFileInfo($fid));
$obj->template->set_vars('file_type', PSMT::File->GetFileExt($fid));

$obj->template->process('fileinfo');

exit;

