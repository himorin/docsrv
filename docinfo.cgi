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
use PSMT::Label;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $did = $obj_cgi->param('did');
if (! defined($did)) {PSMT::Error->throw_error_user('invalid_document_id'); }

if ($obj_cgi->request_method() eq 'POST') {
    my $name = $obj_cgi->param('docname');
    my $desc = $obj_cgi->param('description');
    if (defined($name) && defined($desc)) {
        PSMT::File->UpdateDocInfo($did, $name, $desc);
    }
}

my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }

# check permission
PSMT::Access->CheckForDoc($did);

my $file_list = PSMT::File->GetDocFiles($did);
my @file_users;
foreach (@$file_list) {push(@file_users, $_->{uname}); }

# insert parameters
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('doc_labels', PSMT::Label->ListLabelOnDoc($did));
$obj->template->set_vars('file_list', $file_list);
$obj->template->set_vars('file_uname', \@file_users);
$obj->template->set_vars('activity', PSMT::File->ListUserLoadForDoc($did));
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('docinfo', 'html');


exit;

