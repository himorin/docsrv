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

my $pathinfo = undef;
my $pid = $obj_cgi->param('pid');
if (defined($pid) && ($pid != 0)) {
    # first check pid is valid; if valid clear path
    $pathinfo = PSMT::File->GetPathInfo($pid);
    if (! defined($pathinfo)) {
        PSMT::Error->throw_error_user('invalid_path_id');
    }
} else {
    PSMT::Error->throw_error_user('invalid_path_id');
}

# check permission
if (PSMT::File->UserCanAccessPath($pid) != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

# Register file
if ($obj_cgi->request_method() eq 'POST') {
    my $source = $obj_cgi->param('source');
    my $desc = $obj_cgi->param('comment');
    my $filename = $obj_cgi->param('filename');
    my $docdesc = $obj_cgi->param('docdesc');

    # Fiest register new document to path
    my $did = PSMT::File->RegNewDoc($pid, $filename, $docdesc);
    if ($did == 0) {
        PSMT::Error->throw_error_user('doc_add_failed');
    }

    # Add new file from source
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

    print $obj_cgi->header();
    $obj->template->set_vars('pid', $pid);
    $obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
    $obj->template->set_vars('path_info', $pathinfo);
    $obj->template->set_vars('permission', PSMT::File->GetPathAccessGroup($pid));
    $obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));
    $obj->template->set_vars('dav_file', PSMT::File->ListDavFile());
    $obj->template->process('docadd_success', 'html');
    exit;
}

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('permission', PSMT::File->GetPathAccessGroup($pid));
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));
$obj->template->set_vars('dav_file', PSMT::File->ListDavFile());

$obj->template->process('docadd', 'html');


exit;

