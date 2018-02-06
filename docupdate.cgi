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

my $did = $obj_cgi->param('did');
if (! defined($did)) {PSMT::Error->throw_error_user('invalid_document_id'); }

my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }

# check permission
PSMT::Access->CheckForDocobj($docinfo);

# Register file
if ($obj_cgi->request_method() eq 'POST') {
    my $source = $obj_cgi->param('source');
    my $desc = $obj_cgi->param('comment');
    my $demail = $obj_cgi->param('demail');
    my $version = $obj_cgi->param('version');

    my $ext = 'dat';
    my $src = undef;
    my $chash;
    if ($source eq 'dav') {
        $src = $obj_cgi->param('dav_source');
        if (rindex($src, '.') != -1) {$ext = substr($src, rindex($src, '.') + 1); }
        $src = PSMT::Config->GetParam('dav_path') . '/' . $src;
        $chash = PSMT::File->CheckDavHash($src);
    } elsif ($source eq 'upload') {
        my $fh = $obj_cgi->upload('target_file');
        my $fname = $obj_cgi->param('target_file');
        if (! defined($fh)) {PSMT::Error->throw_error_user('null_file_upload'); }
        $src = PSMT::File->SaveToDav($fh, \$chash);
        if (rindex($fname, '.') != -1) {$ext = substr($fname, rindex($fname, '.') + 1); }
    } else {
        PSMT::Error->throw_error_user('invalid_file_source');
    }

    my $fid = PSMT::File->RegNewFile($ext, $did, $desc, TRUE, $src, $chash, 
                                     $demail, $version);
    if (! defined($fid)) {
        PSMT::Error->throw_error_user('file_register_failed');
    }

    $obj->template->set_vars('added', $fid);
}

# insert parameters
$docinfo->{'next_version'} = PSMT::File->GetNextVersionForDoc($did);
$obj->template->set_vars('dav_file', PSMT::File->ListDavFile());
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('file_list', PSMT::File->ListFilesInDoc($did));
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('docupdate', 'html');


exit;

