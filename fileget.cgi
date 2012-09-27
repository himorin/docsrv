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

my $fid = undef;
my $did = $obj_cgi->param('did');
if (defined($did)) {$fid = PSMT::File->GetDocLastPostFileId($did); }
if (! defined($fid)) {$fid = $obj_cgi->param('fid'); }
if (! defined($fid)) {PSMT::Error->throw_error_user('invalid_fileid'); }
my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }

# check permission
PSMT::Access->CheckForFile($fid);

# download
my $file = PSMT::File->GetFilePath($fid) . $fid;
if (! -f $file) {PSMT::Error->throw_error_user('invalid_filepath'); }
my $fname = PSMT::File->GetFileFullPath($fid);
if (! defined($fname)) {$fname = $fid; }
PSMT::File->RegUserAccess($fid);

binmode STDOUT, ':bytes';
# Encrypted zip or not
if (TRUE) {
    my $pass = PSMT::Util->GetHashString($fid);
    my $fh = PSMT::File->MakeEncZipFile($fid, $pass);
    if (! defined($fh)) {PSMT::Error->throw_error_code('crypt_zip'); }
    print $obj_cgi->header(
            -type => PSMT::File->GetFileExt("zip") . "; name=\"$fname.zip\"",
            -content_disposition => "attachment; filename=\"$fname.zip\"",
        );
    print <$fh>;
    close($fh);
    PSMT::Email->SendPassword($fid, PSMT->user->get_uid(), $pass);
} else {
    my $ext = PSMT::File->GetFileExt($fid);
    # Quick hack for MSKB #436616
    if ($ENV{'HTTP_USER_AGENT'} =~ / MSIE /) {
        utf8::encode($fname);
        $fname =~ s/([^\w ])/'%' . unpack('H2', $1)/eg;
    }
    print $obj_cgi->header(
            -type => "$ext; name=\"$fname\"",
            -content_disposition => "attachment; filename=\"$fname\"",
            -content_length => PSMT::File->GetFileSize($fid),
        );
    binmode STDOUT, ':bytes';
    open(INDAT, $file);
    print <INDAT>;
    close(INDAT);
}

exit;

