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

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

my ($lid, $linfo);
$lid = $obj_cgi->param('lid');

# for update
if ($obj_cgi->request_method() eq 'POST') {
    my $newname = $obj_cgi->param('lname');
    my $newdesc = $obj_cgi->param('ldesc');
    if ($lid == 0) {
        $lid = PSMT::Label->AddNewLabel($newname, $newdesc);
        if ($lid == 0) {PSMT::Error->throw_error_code('failed_to_add_label'); }
    } else {
        $linfo = PSMT::Label->GetLabelInfo($lid);
        if (! defined($linfo)) {PSMT::Error->throw_error_user('invalid_label_id'); }
        PSMT::Label->UpdateLabel($lid, $newname, $newdesc);
    }
    $linfo = PSMT::Label->GetLabelInfo($lid);
} elsif ($lid == 0) {
    $lid = '0';
} else {
    if (! defined($lid)) {PSMT::Error->throw_error_user('invalid_label_id'); }
    $linfo = PSMT::Label->GetLabelInfo($lid);
    if (! defined($linfo)) {PSMT::Error->throw_error_user('invalid_label_id'); }
}

print $obj_cgi->header();
$obj->template->set_vars('lid', $lid);
$obj->template->set_vars('linfo', $linfo);
$obj->template->process('labeledit', 'html');

exit;

