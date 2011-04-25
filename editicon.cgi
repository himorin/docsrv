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
use PSMT::Skin;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

# check permission - in group admin
if ($obj->user()->is_inadmin() != TRUE) {
    PSMT::Error->throw_error_user('permission_error');
}

my $class = $obj_cgi->param('class');
my $target = $obj_cgi->param('target');
# for UPDATE
if ($obj_cgi->request_method() eq 'POST') {
    print $obj_cgi->header();
    my $icon = $obj_cgi->param('icon');
    my $tiphelp = $obj_cgi->param('tiphelp');
    my $enabled = $obj_cgi->param('enabled');
    PSMT::Skin->UpdateIcon($class, $target, $tiphelp, $icon, $enabled);
    $target = undef;
}

# for targeted
if (defined($class)) {
    $obj->template->set_vars('class', $class);
    $obj->template->set_vars('target', $target);
    my $method = $obj_cgi->param('method');
    if (defined($target)) {
        # select icon from list for specified class/target
        $obj->template->set_vars('avail_icons', PSMT::Skin->ListAvailFiles());
        $obj->template->set_vars('icon_info', PSMT::Skin->GetIconInfo($class, $target));
        $obj->template->process('skins/list', 'html');
    } elsif (($class eq 'mime') && (defined($method)) && ($method eq 'new')) {
        $obj->template->set_vars('avail_icons', PSMT::Skin->ListAvailFiles());
        $obj->template->process('skins/list_new', 'html');
    } else {
        # select target from specified class
        if ($class eq 'table') {
            $obj->template->set_vars('target', PSMT::Skin->ListIconsTable());
        } elsif($class eq 'mime') {
            $obj->template->set_vars('target', PSMT::Skin->ListIconsMime());
        } else {
            PSMT::Error->throw_error_user('unknown_icon_target');
        }
        $obj->template->process('skins/select_target', 'html');
    }
    exit;
}

# general
$obj->template->process('skins/index', 'html');


exit;

