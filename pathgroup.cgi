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
use PSMT::NetLdap;
use PSMT::Access;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
    exit;
}

# check permission - in group admin
if ($obj->user()->is_ingroup('all') != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
    exit;
}

my $pid = $obj_cgi->param('pid');
if (! defined($pid)) {
    PSMT::Error->throw_error_user('invalid_path_id');
    exit;
}
if ($pid == 0) {
    PSMT::Error->throw_error_user('root_cannot_set_permission');
    exit;
}
my $pathinfo = PSMT::File->GetPathInfo($pid);
if (! defined($pathinfo)) {
    PSMT::Error->throw_error_user('invalid_path_id');
    exit;
}

# for update
my @newgroup;
if ($obj_cgi->request_method() eq 'POST') {
    @newgroup = $obj_cgi->param('newgroup');
    PSMT::Access->SetPathAccessGroup($pid, \@newgroup);
}

# elsewise, show config UI
print $obj_cgi->header();

$obj->template->set_vars('new', \@newgroup);

# insert parameters
$obj->template->set_vars('all_groups', $obj->ldap()->GetAvailGroups());
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
$obj->template->set_vars('path_info', $pathinfo);
$obj->template->set_vars('permission', PSMT::Access->ListPathRestrict($pid));

$obj->template->process('pathgroup', 'html');


exit;

