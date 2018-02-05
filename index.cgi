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

# accessed with /
my $fmt = $obj->cgi()->param('fmt');
if (defined($fmt) && ($fmt eq 'ur')) {
    my $url = PSMT->user_config->Config()->{'home'}->{value};
    # if required pure index.cgi do nothing
    if ((substr($url, 0, 1) ne '/') && (substr($url, 0, 9) ne 'index.cgi')) {
        my $curl = $obj->cgi()->url();
        if (substr($curl, -3) eq '.cgi') {$curl = substr($curl, 0, index($curl, '/') + 1); }
        elsif (substr($curl, -1) ne '/') {$curl .= '/'; }
        print $obj->cgi()->redirect($curl . $url);
        exit;
    }
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
$obj->template->set_vars('topdirs', PSMT::File->ListPathInPath(0));
$obj->template->set_vars('doc_list', PSMT::File->ListDocsInPath(0));
$obj->template->set_vars('recent', PSMT::Search->RecentUpdate(PSMT->user_config->Config()->{history}->{value}));
$obj->template->process('index', 'html');


exit;

