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

my $max_read = 65536;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $fid = undef;
my $did = $obj_cgi->param('did');
my $ext = $obj_cgi->param('ext');
my $conv = $obj_cgi->param('conv');
if (defined($did)) {$fid = PSMT::File->GetDocLastPostFileId($did, $ext); }
if (! defined($fid)) {$fid = $obj_cgi->param('fid'); }
if (! defined($fid)) {PSMT::Error->throw_error_user('invalid_fileid'); }
my $fileinfo = PSMT::File->GetFileInfo($fid);
if (! defined($fileinfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }
if (defined($conv)) {
    if (defined(OOXML_CONV_TO->{$fileinfo->{fileext}})) {
        $conv = OOXML_CONV_TO->{$fileinfo->{fileext}};
    }
    if (! defined($conv)) {PSMT::Error->throw_error_user('invalid_param'); }
}

my $q_range = $ENV{'HTTP_RANGE'};
my $q_method = $ENV{'REQUEST_METHOD'};
if (! defined($q_method)) {$q_method = 'GET'; }
my ($qr_start, $qr_end);
if (defined($q_range)) {
    if ($q_range !~ /^bytes=([0-9]+)-([0-9]+)$/) {
        PSMT::Error->throw_error_user('invalid_param');
    }
    $qr_start = $1;
    $qr_end = $2;
}

# check permission
PSMT::Access->CheckForFile($fid);

# download
my $file = PSMT::File->GetFilePath($fid) . $fid;
if (defined($conv)) {$file .= '.' . $conv; }
if (! -f $file) {PSMT::Error->throw_error_user('invalid_filepath'); }
my $fname = PSMT::File->GetFileFullPath($fid);
if (! defined($fname)) {$fname = $fid; }
# if access with range, starting not from 0, not register
if ((! (defined($q_range) && ($qr_start != 0))) && ($q_method ne 'HEAD')) {
    PSMT::File->RegUserAccess($fid);
}
$fname =~ s/\//_/g;

binmode STDOUT, ':bytes';
my $ext;
if (defined($conv)) {$ext = PSMT::Util->GetMimeType($conv); }
else {$ext = PSMT::Util->GetMimeType($fileinfo->{fileext}); }
my $fsize = (-s $file);
if ($q_method eq 'HEAD') {
    print "Content-Type: $ext\n";
    print "Content-Length: " . $fsize . "\n";
    print "Accept-Ranges: bytes\n";
    print "\n";
    exit;
}
if (PSMT::Access->CheckSecureForFile($fid)) {
#    by zip encrypted
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
} elsif (PSMT::File->CheckMimeIsView($ext)) {
    print $obj_cgi->header(
            -type => "$ext",
            -content_length => $fsize,
        );
    binmode STDOUT, ':bytes';
    open(INDAT, $file);
    print <INDAT>;
    close(INDAT);
} elsif (! defined($q_range)) {
#   just download
    # Quick hack for MSKB #436616
    if ($ENV{'HTTP_USER_AGENT'} =~ / MSIE /) {
        utf8::encode($fname);
        $fname =~ s/([^\w ])/'%' . unpack('H2', $1)/eg;
        $fname .= '.' . $fileinfo->{fileext};
    }
    print $obj_cgi->header(
            -type => "$ext; name=\"$fname\"",
            -content_disposition => "attachment; filename=\"$fname\"",
            -content_length => $fsize,
            -accept_ranges => 'bytes',
        );
    binmode STDOUT, ':bytes';
    open(INDAT, $file);
    print <INDAT>;
    close(INDAT);
} else {
#   just download
    # Quick hack for MSKB #436616
    if ($ENV{'HTTP_USER_AGENT'} =~ / MSIE /) {
        utf8::encode($fname);
        $fname =~ s/([^\w ])/'%' . unpack('H2', $1)/eg;
        $fname .= '.' . $fileinfo->{fileext};
    }
    print $obj_cgi->header(
            -type => "$ext; name=\"$fname\"",
            -content_disposition => "attachment; filename=\"$fname\"",
            -content_length => ($qr_end - $qr_start + 1),
            -content_range => "bytes $qr_start-$qr_end/" . $fsize,
            -accept_ranges => 'bytes',
        );
    binmode STDOUT, ':bytes';
    open(INDAT, $file);
    seek(INDAT, 0, $qr_start);
    my $cpos = $qr_start;
    my $cbuf;
    while (($cpos + $max_read) < $qr_end) {
        read INDAT, $cbuf, $max_read;
        print $cbuf;
        $cpos += $max_read;
    }
    read INDAT, $cbuf, ($qr_end - $cpos + 1);
    print $cbuf;
    close(INDAT);
}


exit;

