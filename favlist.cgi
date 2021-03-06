#! /usr/bin/perl

use strict;
use lib '.';
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

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

# favorites
my $favs = PSMT->user->ListFavsDoc();
my $favdocs = PSMT::File->GetDocsInfo($favs);
foreach (keys(%$favdocs)) {
    $favdocs->{$_}->{full_path} = PSMT::File->GetFullPathFromId($favdocs->{$_}->{pathid});
}

my $favpath;
$favs = PSMT->user->ListFavsPath();
$favpath = PSMT::File->GetPathsInfo($favs);
foreach (keys(%$favpath)) {
    $favpath->{$_}->{full_path} = PSMT::File->GetFullPathFromId($_);
}

$obj->template->set_vars('favs', $favdocs);
$obj->template->set_vars('favs_path', $favpath);
$obj->template->process('favlist', 'html');


exit;

