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
PSMT::Access->CheckForFile($fid);

# download
my $file = PSMT::File->GetFilePath($fid) . $fid;
if (! -f $file) {
    PSMT::Error->throw_error_user('invalid_filepath');
    exit;
}

my $ext = PSMT::File->GetFileExt($fid);
PSMT::File->RegUserAccess($fid);

print $obj_cgi->header($ext);
open(INDAT, $file);
print <INDAT>;
close(INDAT);

exit;

