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

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
    exit;
}

print $obj->cgi()->header();

# favorites
my %favdocs;
my $favs = PSMT->user->ListFavs();
foreach (@$favs) {
    $favdocs{$_} = PSMT::File->GetDocInfo($_);
    $favdocs{$_}->{full_path} = PSMT::File->GetFullPathFromId($favdocs{$_}->{pathid});
}

$obj->template->set_vars('favs', \%favdocs);
$obj->template->process('index', 'html');


exit;

