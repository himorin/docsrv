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

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $fid = $obj_cgi->param('fid');
if (! defined($fid)) {PSMT::Error->throw_error_user('invalid_fileid'); }
my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }
if (! $fileinfo->{preview}) {PSMT::Error->throw_error_user('invalid_fileid'); }
# check permission
PSMT::Access->CheckForFile($fid);
if (PSMT::Access->CheckSecureForFile($fid)) {
    PSMT::Error->throw_error_user('invalid_fileid');
}

$obj->template->set_vars('fileinfo', $fileinfo);
$obj->template->process('preview', 'html');

exit;

