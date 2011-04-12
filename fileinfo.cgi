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

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
    exit;
}

my $fid = $obj_cgi->param('fid');
if (! defined($fid)) {
    PSMT::Error->throw_error_user('invalid_fileid');
    exit;
}

my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {
    PSMT::Error->throw_error_user('invalid_fileid');
    exit;
}

# check permission
if (PSMT::File->UserCanAccessDoc($fileinfo->{docid}) != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
    exit;
}

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('user_load', PSMT::File->ListUserLoad($fid));
$obj->template->set_vars('file_info', PSMT::File->GetFileInfo($fid));
$obj->template->set_vars('file_type', PSMT::File->GetFileExt($fid));

$obj->template->process('fileinfo.html.tmpl');


exit;

