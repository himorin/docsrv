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
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

# check permission - in group admin
if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

# IF POST, check delete
my (@deleted, $cname);
if ($obj_cgi->request_method() eq 'POST') {
    my @pname = $obj_cgi->param('target_path');
    if ($#pname > -1) {
        foreach (@pname) {
            $cname = PSMT::File->GetFullPathFromId($_);
            if (PSMT::File->DeleteEmptyPath($_)) {push(@deleted, $cname); }
        }
    }
}

# default to list path could be deleted
my $plist = PSMT::File->ListNullPath();
my %phash;
foreach (@$plist) {$phash{$_} = PSMT::File->GetFullPathFromId($_); }
$obj->template->set_vars('targets', \%phash);
$obj->template->set_vars('deleted', \@deleted);
$obj->template->process('delpath', 'html');

exit;

