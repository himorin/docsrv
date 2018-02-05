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

my $pathinfo = undef;

# definition : pid > path
my $pid = $obj_cgi->param('pid');
my $path = $obj_cgi->param('path');
my $path_info = $obj_cgi->path_info();
if (defined($pid)) {
    if ($pid == 0) {$path = undef; }
    else {
        # first check pid is valid; if valid clear path
        $pathinfo = PSMT::File->GetPathInfo($pid);
        if (defined($pathinfo)) {$path = undef; }
    }
}
if (defined($path_info) && (! defined($path)) && (! defined($pid))) {
    $path = $path_info;
}
# make $path at last
if (defined($path)) {
    # if path != undef, make path/pid from path
    $pid = PSMT::File->GetIdFromFullPath($path);
    # not allow '/' for path (if not pid=0 mode)
    if ($pid == 0) {PSMT::Error->throw_error_user('invalid_path_id'); }
    $pathinfo = PSMT::File->GetPathInfo($pid);
} elsif (defined($pid)) {
    if ($pid == 0) {$path = '/'; }
} elsif ($obj_cgi->request_method() eq 'POST') {
    # NOT allow path is empty for POST
    PSMT::Error->throw_error_user('invalid_path_id');
} else {
    # For default, use pid = 0 (root)
    $pid = 0;
    $path = '/';
}
if ($pid > 0) {
    $path = PSMT::File->GetFullPathFromId($pid);
} elsif ($pid < 0) {
    PSMT::Error->throw_error_user('invalid_path_id');
}

# check permission
PSMT::Access->CheckForPath($pid);

if ($obj_cgi->request_method() eq 'POST') {
    my (%old, %new);
    $old{name} = $obj_cgi->param('old_name');
    $old{parent} = $obj_cgi->param('old_parent');
    $old{description} = $obj_cgi->param('old_description');
    $new{name} = $obj_cgi->param('new_name');
    $new{parent} = $obj_cgi->param('new_parent');
    $new{description} = $obj_cgi->param('new_description');
    PSMT::File->UpdatePathInfo($pid, \%old, \%new);
    $pathinfo = PSMT::File->GetPathInfo($pid);
    $path = PSMT::File->GetFullPathFromId($pid);
}

# insert parameters
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', $path);
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));

my $subpath = PSMT::File->ListPathInPath($pid);
my %subpath_access;
foreach (keys(%$subpath)) {
    $subpath_access{$_} = PSMT::Access->ListPathRestrict($_);
}
$obj->template->set_vars('spath_list', $subpath);
$obj->template->set_vars('spath_access', \%subpath_access);
$obj->template->set_vars('dav_file', PSMT::File->ListDavFile());

$obj->template->process('pathinfo', 'html');

exit;

