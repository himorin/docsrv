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

my $did = $obj_cgi->param('did');
if (! defined($did)) {
    PSMT::Error->throw_error_user('invalid_document_id');
    exit;
}

my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {
    PSMT::Error->throw_error_user('invalid_document_id');
    exit;
}

# check permission
if (PSMT::File->UserCanAccessDoc($did) != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
    exit;
}

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('file_list', PSMT::File->GetDocFiles($did));
$obj->template->set_vars('group_list', PSMT::File->GetDocAccessGroup($did));

$obj->template->process('docinfo.html.tmpl');


exit;

