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

my $obj = new PSMT;

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

# favorites
my %favdocs;
my $favs = PSMT->user->ListFavsDoc();
foreach (@$favs) {
    $favdocs{$_} = PSMT::File->GetDocInfo($_);
    $favdocs{$_}->{full_path} = PSMT::File->GetFullPathFromId($favdocs{$_}->{pathid});
    $favdocs{$_}->{fid} = PSMT::File->GetDocLastPostFileInfo($_);
}
my %favpath;
$favs = PSMT->user->ListFavsPath();
foreach (@$favs) {
    $favpath{$_} = PSMT::File->GetPathInfo($_);
    $favpath{$_}->{full_path} = PSMT::File->GetFullPathFromId($_);
}

$obj->template->set_vars('favs', \%favdocs);
$obj->template->set_vars('favs_path', \%favpath);
$obj->template->set_vars('topdirs', PSMT::File->ListPathInPath(0));
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath(0));
$obj->template->set_vars('recent', PSMT::Search->RecentUpdate(PSMT->user_config->Config()->{history}->{value}));
$obj->template->process('index', 'html');


exit;

