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
my $dname = $obj_cgi->param('doc');
my $path_info = $obj_cgi->path_info();
if (! (defined($did) || defined($dname))) {
    if (! defined($path_info)) {
        PSMT::Error->throw_error_user('invalid_document_id');
    } else {
        $dname = $path_info;
    }
}
if (defined($dname) && (! defined($did))) {
    $did = PSMT::File->GetIdFromFullName($dname);
    if ($did == 0) {
        PSMT::Error->throw_error_user('invalid_document_id');
    }
}

if ($obj_cgi->request_method() eq 'POST') {
    my (%old, %new);
    $old{name} = $obj_cgi->param('old_name');
    $old{pathid} = $obj_cgi->param('old_pathid');
    $old{description} = $obj_cgi->param('old_description');
    $old{secure} = $obj_cgi->param('old_secure');
    $new{name} = $obj_cgi->param('new_name');
    $new{pathid} = $obj_cgi->param('new_pathid');
    $new{description} = $obj_cgi->param('new_description');
    $new{secure} = defined($obj_cgi->param('new_secure')) ? 1 : 0;
    PSMT::File->UpdateDocInfo($did, \%old, \%new);
}

my $docinfo = PSMT::File->GetDocInfo($did);
if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }

# check permission
PSMT::Access->CheckForDoc($did);

my $file_list = PSMT::File->ListFilesInDoc($did);
my @file_users;
foreach (@$file_list) {push(@file_users, $_->{uname}); }
my %hash;
PSMT::File->ListAllPath(\%hash);

# insert parameters
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
$obj->template->set_vars('doc_info', $docinfo);
$obj->template->set_vars('doc_labels', PSMT::Label->ListLabelOnDoc($did));
$obj->template->set_vars('file_list', $file_list);
$obj->template->set_vars('file_uname', \@file_users);
$obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));

$obj->template->process('docinfo', 'html');


exit;

