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

# check permission - in group admin
if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

$obj->template->process('admin', 'html');

exit;

