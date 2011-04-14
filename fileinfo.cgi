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

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $fid = $obj_cgi->param('fid');
if (! defined($fid)) {PSMT::Error->throw_error_user('invalid_fileid'); }

my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }

# check permission
PSMT::Access->CheckForFile($fid);

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('user_load', PSMT::File->ListUserLoad($fid));
$obj->template->set_vars('file_info', PSMT::File->GetFileInfo($fid));
$obj->template->set_vars('file_type', PSMT::File->GetFileExt($fid));

$obj->template->process('fileinfo', 'html');

exit;

