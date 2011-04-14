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
}

# check permission - in group admin
if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

my $did = $obj_cgi->param('did');
if (! defined($did)) {PSMT::Error->throw_error_user('invalid_doc_id'); }
my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_doc_id'); }
PSMT::Access->CheckForDoc($did);

# for update
my @newlabel;
if ($obj_cgi->request_method() eq 'POST') {
    @newlabel = $obj_cgi->param('newlabel');
    PSMT::Label->ModLabelOnDoc($did, \@newlabel);
}

$docinfo = PSMT::File->GetDocInfo($did);

# insert parameters
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('did', $did);
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('label_list', PSMT::Label->ListLabelOnDoc($did));
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('doclabel', 'html');

exit;

