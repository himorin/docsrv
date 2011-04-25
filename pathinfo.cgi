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
if (defined($pid)) {
    if ($pid == 0) {$path = undef; }
    else {
        # first check pid is valid; if valid clear path
        $pathinfo = PSMT::File->GetPathInfo($pid);
        if (defined($pathinfo)) {$path = undef; }
    }
}
if (defined($path)) {
    # if path != undef, make path/pid from path
    $pid = PSMT::File->GetIdFromFullPath($path);
    # not allow '/' for path (if not pid=0 mode)
    if ($pid == 0) {PSMT::Error->throw_error_user('invalid_path_id'); }
    $pathinfo = PSMT::File->GetPathInfo($pid);
} elsif (defined($pid)) {
    if ($pid == 0) {$path = '/'; }
    else {
        # create path from pid
        $path = PSMT::File->GetFullPathFromId($pid);
    }
} else {PSMT::Error->throw_error_user('invalid_path_id'); }

# check permission
PSMT::Access->CheckForPath($pid);

if ($obj_cgi->request_method() eq 'POST') {
    my $name = $obj_cgi->param('pathname');
    my $desc = $obj_cgi->param('description');
    if (defined($name) && defined($desc)) {
        PSMT::File->UpdatePathInfo($pid, $name, $desc);
    }
    $pathinfo = PSMT::File->GetPathInfo($pid);
}

# insert parameters
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', $path);
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));

my $subpath = PSMT::File->ListPathInPath($pid);
my (%subpath_access, $cpid);
foreach (@$subpath) {
    $cpid = $_->{pathid};
    $subpath_access{$cpid} = PSMT::Access->ListPathRestrict($cpid);
}
$obj->template->set_vars('spath_list', $subpath);
$obj->template->set_vars('spath_access', \%subpath_access);

$obj->template->process('pathinfo', 'html');

exit;

