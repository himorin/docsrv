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
use PSMT::NetLdap;
use PSMT::Access;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $hash;
my $type = $obj_cgi->param('type');

if ($type eq 'allpath') {
    PSMT::File->ListAllPath($hash);
} else {
    PSMT::Error->throw_error_user('invalid_param');
}

$obj->template->set_vars('type', $type);
$obj->template->set_vars('jsondata', $hash);

$obj_cgi->header( -type => "application/json" );
$obj->template->process('json', 'json');

exit;

