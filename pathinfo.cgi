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

my $pid = $obj_cgi->param('pid');
if (! defined($pid)) {
    PSMT::Error->throw_error_user('invalid_path_id');
    exit;
}

my $pathinfo = PSMT::File->GetPathInfo($pid);
if (! defined($pathinfo)) {
    PSMT::Error->throw_error_user('invalid_path_id');
    exit;
}

# check permission
if (PSMT::File->UserCanAccessPath($pid) != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
    exit;
}

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('permission', PSMT::File->GetPathAccessGroup($pid));
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath($pid));

my $subpath = PSMT::File->ListPathInPath($pid);
my (%subpath_access, $cpid);
foreach (@$subpath) {
    $cpid = $_->{pathid};
    $subpath_access{$cpid} = PSMT::File->GetPathAccessGroup($cpid);
}
$obj->template->set_vars('spath_list', $subpath);
$obj->template->set_vars('spath_access', \%subpath_access);

$obj->template->process('pathinfo.html.tmpl');


exit;

