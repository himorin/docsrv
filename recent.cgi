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
use PSMT::Search;

my $obj = new PSMT;

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

$obj->template->set_vars('recent', PSMT::Search->RecentUpdate(PSMT->user_config->Config()->{history}->{value}));
$obj->template->process('recent', 'html');

exit;

