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

my $op = $obj_cgi->param('op');
my $did = $obj_cgi->param('did');
my $pid = $obj_cgi->param('pid');

# if both undef or both def, error
if (defined($did) == defined($pid)) {PSMT::Error->throw_error_user('invalid_param'); }

if (defined($did)) {
  my $docinfo = PSMT::File->GetDocInfo($did);
  if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }
  # check permission
  PSMT::Access->CheckForDoc($did);
  if ($op eq 'add') {PSMT->user->MakeFavDoc($did); } 
  elsif ($op eq 'remove') {PSMT->user->RemoveFavDoc($did); } 
  else {PSMT::Error->throw_error_user('unknown_operation_method'); }
  $obj->template->set_vars('did', $did);
  $obj->template->set_vars('doc_info', $docinfo);
  $obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
  $obj->template->set_vars('file_list', PSMT::File->ListFilesInDoc($did));
  $obj->template->set_vars('group_list', PSMT::Access->ListDocRestrict($did));
} else {
  my $pathinfo = PSMT::File->GetPathInfo($pid);
  if (! defined($pathinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }
  # check permission
  PSMT::Access->CheckForPath($pid);
  if ($op eq 'add') {PSMT->user->MakeFavPath($pid); } 
  elsif ($op eq 'remove') {PSMT->user->RemoveFavPath($pid); } 
  else {PSMT::Error->throw_error_user('unknown_operation_method'); }
  $obj->template->set_vars('pid', $pid);
  $obj->template->set_vars('path_info', $pathinfo);
  $obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
}


print $obj_cgi->header();
$obj->template->set_vars('op', $op);
$obj->template->process('docfav');

exit;

