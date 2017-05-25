#! /usr/bin/perl

use strict;
use PSMT;

use PSMT::Constants;
use PSMT::Template;
use PSMT::Config;
use PSMT::CGI;
use PSMT::User;
use PSMT::Util;
use PSMT::File;
use PSMT::Access;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

# need admin for this page
if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}
if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

# PROCESS MERGE
if ($obj_cgi->request_method() eq 'POST') {
    PSMT::Error->throw_error_user('NOT IMPLEMENTED YET');
}


# Display
my $did = $obj_cgi->param('did');
my $dinfo = PSMT::File->GetDocInfo($did);
$obj->template->set_vars('did', $did);
$obj->template->set_vars('doc_info', $dinfo);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($dinfo->{pathid}));
$obj->template->set_vars('doc_labels', PSMT::Label->ListLabelOnDoc($did));
$obj->template->set_vars('file_list', PSMT::File->ListFilesInDoc($did, TRUE));

my %allpath;
PSMT::File->ListAllPath(\%allpath);
$obj->template->set_vars('allpath', \%allpath);
$obj->template->set_vars('allpathrev', PSMT::Util->MakeReverseHashByKey(\%allpath, 'fullpath'));

$obj->template->process('docmerge', 'html');

exit;

