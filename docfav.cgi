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

my $did = $obj_cgi->param('did');
my $op = $obj_cgi->param('op');
if (! defined($did)) {PSMT::Error->throw_error_user('invalid_document_id'); }
my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }

# check permission
PSMT::Access->CheckForDoc($did);

if ($op eq 'add') {PSMT->user->MakeFav($did); } 
elsif ($op eq 'remove') {PSMT->user->RemoveFav($did); } 
else {PSMT::Error->throw_error_user('unknown_operation_method'); }

print $obj_cgi->header();

# insert parameters
$obj->template->set_vars('op', $op);
$obj->template->set_vars('did', $did);
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('file_list', PSMT::File->GetDocFiles($did));
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('docfav', 'html');

exit;

