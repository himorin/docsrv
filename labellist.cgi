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
use PSMT::Access;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $labels = PSMT::Label->ListAllLabel();

foreach (keys %$labels) {
    $labels->{$_}{group} = PSMT::Access->ListLabelRestrict($_);
}

print $obj_cgi->header();
$obj->template->set_vars('labels', $labels);
$obj->template->process('labellist', 'html');

exit;

