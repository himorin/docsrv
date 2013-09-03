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
use PSMT::Search;

use PSMT::HyperEstraier;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

if ($obj_cgi->request_method() ne 'POST') {
    print $obj_cgi->redirect('search.cgi');
    exit;
}
my %p_sc;
foreach ($obj_cgi->param('searchcond')) {$p_sc{$_} = 1; }

my $docs_he = $obj_cgi->param('docs_he');
# XXX to modify...
if (defined($p_sc{'sc_full'}) && defined($docs_he) && ($docs_he ne '')) {
    my $obj_he = new PSMT::HyperEstraier();
    my $res = $obj_he->ExecSearch($docs_he);
    my (@data, $finfo, $dinfo);
    foreach (@$res) {
        if (! PSMT::Access->CheckForFile($_)) {next; }
        $finfo = PSMT::File->GetFileInfo($_);
        $dinfo = PSMT::File->GetDocInfo($finfo->{docid});
        $dinfo->{filename} = PSMT::File->GetFullPathFromId($dinfo->{pathid}) . $dinfo->{filename};
        $dinfo->{labelid} = PSMT::Label->ListLabelOnDoc($dinfo->{docid});
        $finfo->{size} = PSMT::File->GetFileSize($_);
        $dinfo->{lastfile} = $finfo;
        push(@data, $dinfo);
    }
    $obj->template->set_vars('search_result', \@data);
    $obj->template->process('search/query', 'html');
    exit;
}

    my %conf;
    my $cond = $obj_cgi->param('global_cond');
if (defined($p_sc{'sc_item'})) {
    my $docreg_desc_input = $obj_cgi->param('docreg_desc');
    my $docreg_desc_cond = $obj_cgi->param('docreg_desc_cond');
    my @doc_label = $obj_cgi->param('doc_label');
    my $doc_label_cond = $obj_cgi->param('doc_label_cond');

    my @docreg_desc = split(/ /, $docreg_desc_input);

    if ($#docreg_desc > -1) {
        $conf{docreg_desc} = \@docreg_desc;
        $conf{docreg_desc_cond} = $docreg_desc_cond;
    }
    if ($#doc_label > -1) {
        $conf{doc_label} = \@doc_label;
        $conf{doc_label_cond} = $doc_label_cond;
    }
}

# output
$obj->template->set_vars('search_result', PSMT::Search->Search(\%conf, $cond));
$obj->template->process('search/query', 'html');

exit;

