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

my $did = $obj_cgi->param('did');
if (! defined($did)) {
    PSMT::Error->throw_error_user('invalid_document_id');
    exit;
}

my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {
    PSMT::Error->throw_error_user('invalid_document_id');
}

# check permission
PSMT::Access->CheckForDoc($did);

# Register file
if ($obj_cgi->request_method() eq 'POST') {
    my $source = $obj_cgi->param('source');
    my $desc = $obj_cgi->param('comment');
    my $ext;
    my $src = undef;
    if ($source eq 'dav') {
        $src = $obj_cgi->param('dav_source');
        if (rindex($src, '.') == -1) {$ext = 'dat'; }
        else {$ext = substr($src, rindex($src, '.') + 1); }
    } elsif ($source eq 'upload') {
    } else {
        PSMT::Error->throw_error_user('invalid_file_source');
    }

    my $fid = PSMT::File->RegNewFile($ext, $did, $desc);
    if (! defined($fid)) {
        PSMT::Error->throw_error_user('file_register_failed');
    }
    $src = PSMT::Config->GetParam('dav_path') . '/' . $src;
    if (PSMT::File->MoveNewFile($src, $fid) != TRUE) {
        PSMT::Error->throw_error_user('file_register_failed');
    }

    $obj->template->set_vars('added', $fid);
}

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('dav_file', PSMT::File->ListDavFile());
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('file_list', PSMT::File->GetDocFiles($did));
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('docupdate', 'html');


exit;

