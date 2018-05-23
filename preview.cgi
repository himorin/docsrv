#! /usr/bin/perl

use strict;
use lib '.';
use PSMT;

use File::Basename qw(dirname);

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
if ((IS_PREVIEW->{$fileinfo->{preview}} eq 'libreoffice') && 
    (! defined(OOXML_CONV_TO->{$fileinfo->{fileext}}))) {
    PSMT::Error->throw_error_user('libreoffice_converr');
}
if (IS_PREVIEW->{$fileinfo->{preview}} eq 'fits') {
    if (PSMT::Config->GetParam('imagemagick') eq '') {
        PSMT::Error->throw_error_user('imagemagick_missing');
    }
    my $forig = PSMT::File->GetFilePath($fid) . $fid;
    my $cmd = PSMT::Config->GetParam('imagemagick') . ' ' . $forig . ' ' . $forig . '.png';
    if (! -f $forig . '.png') {
        open(INPROC, "$cmd |");
        close(INPROC);
    }
    if (! -f $forig . '.png') {
        PSMT::Error->throw_error_user('imagemagick_converter');
    }
}
if (defined(OOXML_CONV_TO->{$fileinfo->{fileext}})) {
    if (PSMT::Config->GetParam('libreoffice') eq '') {
        PSMT::Error->throw_error_user('libreoffice_missing');
    }
    my $forig = PSMT::File->GetFilePath($fid) . $fid;
    my $text = OOXML_CONV_TO->{$fileinfo->{fileext}};
    my $fname = $forig . '.' . $text;
    if (! -f $fname) {
        my $fdir = dirname($fname);
        my $cmd = OOXML_OPT;
        $cmd =~ s/{ext}/$text/;
        $cmd =~ s/{dir}/$fdir/;
        $cmd = PSMT::Config->GetParam('libreoffice') . ' ' . $cmd . ' ' . $forig;
        open(INPROC, "$cmd |");
        close(INPROC);
        if (! -f $fname) {
            PSMT::Error->throw_error_user('libreoffice_converr');
        }
    }
    $obj->template->set_vars('conv', OOXML_CONV_TO->{$fileinfo->{fileext}});
}

$obj->template->set_vars('previewmode', IS_PREVIEW->{PSMT::Util->IsPreview($fileinfo->{filemime})});
$obj->template->set_vars('fileinfo', $fileinfo);
$obj->template->process('preview', 'html');

exit;

