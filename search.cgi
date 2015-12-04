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
}
if (($obj_cgi->request_method() ne 'POST') ||
    (! defined($obj_cgi->param('searchcond')))) {
    $obj->template->process('search/search', 'html');
    exit;
}

my %p_sc;
foreach ($obj_cgi->param('searchcond')) {$p_sc{$_} = 1; }

my $res_cond = FALSE;
if ($obj_cgi->param('global_cond') eq 'AND') {$res_cond = TRUE; }

# condition merge procedure
#  1. execute query per condition group (checkbox)
#    1a. fulltext index search: make $res_full_fd{fid} = did
#    1b. name and description search
#      1b1. for path - will not merge with doc, file
#      1b2. for doc and file
#  2. merge fulltext and name/description search in fid based
#    AND: AND(fulltext.fid, doc.fid)
#    OR:  OR(fulltext, doc)
#  3. XXX path restriction
# following proceed as 4 -> 5 for performance
#  4. construct output data array
#  5. apply security


my $res_full_fd;      # ${fid} = did
my $res_doc_path;     # hash of pid
my $res_doc_file;     # ${fid} = did
my $res_merge;        # ${fid} = did

my $use_full = FALSE;
my $use_doc  = FALSE;

my $out_path;         # output info array for path (2a.)

# 1a.
my $p_fullindex = $obj_cgi->param('fullindex');
if (defined($p_sc{'sc_full'}) &&
        defined($p_fullindex) && ($p_fullindex ne '')) {
    my $obj_fti = new PSMT::FullSearchMroonga();
    $res_full_fd = $obj_fti->ExecSearchHash($p_fullindex);
    if ($res_cond && (! defined($res_full_fd))) {&PrintNullResult(); }
    $use_full = TRUE;
}

# 1b.
my $p_cnd_name = $obj_cgi->param('cnd_name');
my $p_cnd_desc = $obj_cgi->param('cnd_desc');
if (! (defined($p_sc{'sc_name'} &&
        defined($p_cnd_name) && ($p_cnd_name ne '')))) {
    $p_cnd_name = undef;
}
if (! (defined($p_sc{'sc_desc'} &&
        defined($p_cnd_desc) && ($p_cnd_desc ne '')))) {
    $p_cnd_desc = undef;
}
if (defined($p_cnd_name) || defined($p_cnd_desc)) {$use_doc = TRUE; }
# check valid condition exist
if (! ($use_full || $use_doc)) {
    $obj->template->process('search/search', 'html');
    exit;
}

# 1b1. path
if ($use_doc) {
    $res_doc_path = PSMT::File->SearchPath($p_cnd_name, $p_cnd_desc, $res_cond);
}
# XXX build hash $out_path from $res_doc_path (might be same?)

# 1b2. doc/file
if ($use_doc) {
    $res_doc_file = PSMT::File->SearchDocFile($p_cnd_name, $p_cnd_desc, $res_cond);
}

#  2. merge fulltext and name/description search in fid based
#    AND: AND(fulltext.fid, doc.fid)
#    OR:  OR(fulltext, doc)
if ($use_full && $use_doc) {
    if ($res_cond) {
        $res_merge = PSMT::Util->MergeHashAnd($res_full_fd, $res_doc_file); 
    } else {
        $res_merge = PSMT::Util->MergeHashOr($res_full_fd, $res_doc_file); 
    }
} elsif ($use_full) {
    $res_merge = $res_full_fd;
} elsif ($use_doc) {
    $res_merge = $res_doc_file;
}

# 3. XXX


# output data array
#  doc{docid} -> fullname, description, array(fid), group, label, pid
#  file{fid}  -> fileext, uptime, uname, size

# 4. and 5.
# did
my $out_doc_fidarr = PSMT::Util->MakeReverseHash($res_merge);
my @tdarr = keys %$out_doc_fidarr;
# this also check by PSMT::Access->CheckForDoc
my $out_doc = PSMT::File->GetDocsInfo(\@tdarr);
foreach (keys %$out_doc) {
    $out_doc->{$_}->{fid} = $out_doc_fidarr->{$_};
}
# fid
@tdarr = keys %$res_merge;
my $out_file = PSMT::File->GetFilesInfo(\@tdarr);

#print "Content-Type: text/plain\n\n";
#use Data::Dumper;
#print Data::Dumper->Dump([ $out_doc ]);

$obj->template->set_vars('list_path', $res_doc_path);
$obj->template->set_vars('list_doc', $out_doc);
$obj->template->set_vars('list_file', $out_file);
$obj->template->process('search/query', 'html');

exit;


sub PrintNullResult {
    $obj->template->set_vars('search', FALSE);
    $obj->template->process('search/query', 'html');
    exit;
}

