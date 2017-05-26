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

my $did = undef;
# PROCESS MERGE
if ($obj_cgi->request_method() eq 'POST') {
    my $opt_delete = $obj_cgi->param('opt_delete');
    my $opt_version = $obj_cgi->param('opt_version');
    my $doc_path = $obj_cgi->param('doc_path');
    my $doc_document = $obj_cgi->param('doc_document');
    my $docdesc = $obj_cgi->param('docdesc');
    my $filename = $obj_cgi->param('filename');
    my @files = $obj_cgi->param('files');
    my $src_document = $obj_cgi->param('src_document');

    if ($#files < 0) {
        PSMT::Error->throw_error_user('no_file_selected');
    }
    if ($doc_document == $src_document) {
        PSMT::Error->throw_error_user('invalid_document_id');
    }
    my $src_flist = PSMT::File->ListFilesInDoc($src_document, TRUE);
    if (! defined($src_flist)) {
        PSMT::Error->throw_error_user('invalid_document_id');
    }
    # cannot merge all files of src into new document
    if (($#$src_flist == $#files) && ($doc_document == 0)) {
        PSMT::Error->throw_error_user('cannot_merge_all_to_new');
    }
    if (($doc_document == 0) && ($filename eq '')) {
        PSMT::Template->set_vars('new_name', $filename);
        PSMT::Template->set_vars('error_id', 'null_name');
        PSMT::Error->throw_error_user('invalid_new_name');
    }
    # check fid all exists
    my $fexist = 0;
    foreach my $cfile (@files) {
        foreach (@$src_flist) {
            if ($cfile eq $_->{fileid}) {$fexist += 1; last; }
        }
    }
    if ($fexist != ($#files + 1)) {
        PSMT::Error->throw_error_user('invalid_file_id');
    }

    # create new document, check security flag
    my $sdinfo = PSMT::File->GetDocInfo($src_document);
    if ($doc_document == 0) {
        $doc_document = PSMT::File->RegNewDoc($doc_path, $filename, $docdesc, 
            $sdinfo->{secure});
        if ($doc_document == 0) {
            PSMT::Error->throw_error_user('doc_add_failed');
        }
    } else {
        my $ddinfo = PSMT::File->GetDocInfo($doc_document);
        if ($sdinfo->{secure} != $ddinfo->{secure}) {
            if ($sdinfo->{secure} == 1) {
                my %newinfo;
                foreach (keys(%$ddinfo)) {$newinfo{$_} = $ddinfo->{$_}; }
                $newinfo{secure} = 1;
                PSMT::File->UpdateDocInfo($doc_document, $ddinfo, \%newinfo);
            }
        }
    }
    # check group permission
    my $gp_src = PSMT::Access->ListFullDocRestrict($src_document);
    my $gp_doc = PSMT::Access->ListDocRestrict($doc_document);
    if ($#$gp_src > -1) {
        if ($#$gp_doc > -1) {
            PSMT::Access->ApplyDocAccessGroup($doc_document, $gp_src, TRUE);
        } else {
            PSMT::Access->SetDocAccessGroup($doc_document, $gp_src);
        }
    }
    # handle version, default to 'keep' (for invalid input...)
    my $file_ver = FALSE;
    if ($opt_version eq 'renumber') {$file_ver = TRUE; }
    # update docid for selected files
    foreach (@files) {
        PSMT::File->UpdateFileDocid($doc_document, $_, $file_ver);
    }
    if ($file_ver) {
        # renumber
        my $new_list = PSMT::File->ListFilesInDoc($doc_document, TRUE);
        my $cver = $#$new_list + 1.0;
        foreach (@$new_list) {
            PSMT::File->UpdateFileVersion($_->{fileid}, $cver);
            $cver -= 1.0;
        }
    }
    # delete old docid if need
    if (($#$src_flist == $#files) && (defined($opt_delete))) {
        PSMT::File->DeleteEmptyDoc($src_document);
    }

    # prepare for display new document (or just redirect?)
    $did = $doc_document;
    $obj->template->set_vars('merged', TRUE);
}


# Display
if (! defined($did)) {$did = $obj_cgi->param('did'); }
my $dinfo = PSMT::File->GetDocInfo($did);
$obj->template->set_vars('did', $did);
$obj->template->set_vars('doc_info', $dinfo);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($dinfo->{pathid}));
$obj->template->set_vars('doc_labels', PSMT::Label->ListLabelOnDoc($did));
$obj->template->set_vars('file_list', PSMT::File->ListFilesInDoc($did, TRUE));

$obj->template->process('docmerge', 'html');

exit;

