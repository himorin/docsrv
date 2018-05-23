#! /usr/bin/perl

use strict;
use lib '.';
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
my $target = $obj_cgi->param('cur_pid');

if (! defined($target)) {PSMT::Error->throw_error_user('invalid_path_id'); }
if ($target != 0) {
    $pathinfo = PSMT::File->GetPathInfo($target);
    if (! defined($pathinfo)) {PSMT::Error->throw_error_user('invalid_path_id'); }
}

# check permission
PSMT::Access->CheckForPath($target);

# add new path
my $newpath = $obj_cgi->param('newpath');
my $newdesc = $obj_cgi->param('newdesc');
my @newgroup = $obj_cgi->param('newgroup');
my $demail = $obj_cgi->param('demail');

my $newid = PSMT::File->RegNewPath($target, $newpath, $newdesc, \@newgroup, $demail);
if ($newid == 0) {PSMT::Error->throw_error_code('path_add_failed'); }

# insert parameters
$obj->template->set_vars('pid', $newid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($newid));
$obj->template->set_vars('path_info', PSMT::File->GetPathInfo($newid));

$obj->template->process('pathadd', 'html');

exit;

