#! /usr/bin/perl

use strict;
use PSMT;

use PSMT::Attribute;
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

print $obj_cgi->header('text/plain');

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $i_target = $obj_cgi->param('target');
my $i_id = $obj_cgi->param('id');
my $i_method = $obj_cgi->param('method');

my $obj_attr = new PSMT::Attribute;
if ($obj_attr->SetTarget($i_target) == FALSE) {
    PSMT::Error->throw_error_user('attr_invalid_target');
}

if (! defined($i_method)) {
    PSMT::Error->throw_error_user('attr_invalid_method');
}
$i_method = lc($i_method);
if ($i_method eq 'list') {
    my @ret = $obj_attr->ListExistAttr($i_id);
    $obj->template->set_vars('list', \@ret);
} elsif ($i_method eq 'get') {
    my $hash = $obj_attr->GetAttrForId($i_id);
    if (! defined($hash)) {print "Error"; }
    $obj->template->set_vars('hash', $hash);
} elsif ($i_method eq 'add') {
    if (! defined($i_id)) {PSMT::Error->throw_error_user('attr_invalid_id'); }
    my $i_attr = $obj_cgi->param('attr');
    my $i_value = $obj_cgi->param('value');
    if (! $obj_attr->AddAttrForId($i_id, $i_attr, $i_value)) {
        PSMT::Error->throw_error_user('attr_already_exist');
    }
    $obj->template->set_vars('attr', $i_attr);
    $obj->template->set_vars('value', $i_value);
} elsif ($i_method eq 'update') {
    if (! defined($i_id)) {PSMT::Error->throw_error_user('attr_invalid_id'); }
    my $i_old = $obj_cgi->param('old_value');
    my $i_new = $obj_cgi->param('new_value');
    if (! $obj_attr->UpdateAttrForId($i_id, $i_attr, $i_old, $i_new)) {
        PSMT::Error->throw_error_user('attr_update_failed');
    }
    $obj->template->set_vars('attr', $i_attr);
    $obj->template->set_vars('old_value', $i_old);
    $obj->template->set_vars('new_value', $i_new);
} else {
    PSMT::Error->throw_error_user('attr_invalid_method');
}

$obj->template->set_vars('id', $i_id);
$obj->template->set_vars('target', $i_target);
# No format specified, default to html
if (! defined(PSMT->cgi()->param('format'))) {
    $obj->template->process('attribute/' . $i_method, 'html');
} else {
    $obj->template->process('attribute/' . $i_method);
}

exit;


my $pathinfo = undef;
my $pid = $obj_cgi->param('pid');
my %allpath;
if (defined($pid) && ($pid != 0) && ($pid != -1)) {
    # first check pid is valid; if valid clear path
    $pathinfo = PSMT::File->GetPathInfo($pid);
    if (! defined($pathinfo)) {
        PSMT::Error->throw_error_user('invalid_path_id');
    }
} elsif ($pid == 0) {
} elsif ($pid == -1) {
    # set target as path list
    PSMT::File->ListAllPath(\%allpath);
} else {
    PSMT::Error->throw_error_user('invalid_path_id');
}

# check permission
if ($pid != -1) {
    PSMT::Access->CheckForPath($pid);
}

# Register file
if ($obj_cgi->request_method() eq 'POST') {
    my $source = $obj_cgi->param('source');
    my $desc = $obj_cgi->param('comment');
    my $filename = $obj_cgi->param('filename');
    my $docdesc = $obj_cgi->param('docdesc');
    my @labels = $obj_cgi->param('label');

    # Add new file from source
    my $ext = 'dat';
    my $src = undef;
    if ($source eq 'dav') {
        $src = $obj_cgi->param('dav_source');
        if (rindex($src, '.') != -1) {$ext = substr($src, rindex($src, '.') + 1); }
        $src = PSMT::Config->GetParam('dav_path') . '/' . $src;
    } elsif ($source eq 'upload') {
        my $fh = $obj_cgi->upload('target_file');
        my $fname = $obj_cgi->param('target_file');
        if (! defined($fh)) {PSMT::Error->throw_error_user('null_file_upload'); }
        $src = PSMT::File->SaveToDav($fh);
        if (rindex($fname, '.') != -1) {$ext = substr($fname, rindex($fname, '.') + 1); }
    } else {
        PSMT::Error->throw_error_user('invalid_file_source');
    }

    # Fiest register new document to path
    my $did = PSMT::File->RegNewDoc($pid, $filename, $docdesc);
    if ($did == 0) {
        PSMT::Error->throw_error_user('doc_add_failed');
    }

    # second register new file to doc
    my $fid = PSMT::File->RegNewFile($ext, $did, $desc, FALSE);
    if (! defined($fid)) {
        PSMT::Error->throw_error_user('file_register_failed');
    }
    if (PSMT::File->MoveNewFile($src, $fid) != TRUE) {
        PSMT::Error->throw_error_user('file_register_failed');
    }
    PSMT::Label->ModLabelOnDoc($did, \@labels);

    $obj->template->set_vars('added', $did);
}

# insert parameters
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('permission', PSMT::Access->ListPathRestrict($pid));
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));
$obj->template->set_vars('path_list', PSMT::File->ListPathInPath($pid));
$obj->template->set_vars('dav_file', PSMT::File->ListDavFile());
$obj->template->set_vars('allpath', \%allpath);

$obj->template->process('docadd', 'html');


exit;

