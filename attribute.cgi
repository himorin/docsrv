#! /usr/bin/perl

use strict;
use PSMT;

use PSMT::Attribute;
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

my $i_target = $obj_cgi->param('target');
my $i_id = $obj_cgi->param('id');
my $i_method = $obj_cgi->param('method');

my $obj_attr = new PSMT::Attribute;
if ($obj_attr->SetTarget($i_target) == FALSE) {
    PSMT::Error->throw_error_user('attr_invalid_target');
}

if (! defined($i_method)) {
    PSMT::Error->throw_error_user('attr_invalid_method');
}
$i_method = lc($i_method);
if ($i_method eq 'list') {
    my @ret = $obj_attr->ListExistAttr($i_id);
    $obj->template->set_vars('list', \@ret);
} elsif ($i_method eq 'get') {
    my $hash = $obj_attr->GetAttrForId($i_id);
    if (! defined($hash)) {print "Error"; }
    $obj->template->set_vars('hash', $hash);
} elsif ($i_method eq 'add') {
    if (! defined($i_id)) {PSMT::Error->throw_error_user('attr_invalid_id'); }
    my $i_attr = $obj_cgi->param('attr');
    my $i_value = $obj_cgi->param('value');
    if (! $obj_attr->AddAttrForId($i_id, $i_attr, $i_value)) {
        PSMT::Error->throw_error_user('attr_already_exist');
    }
    $obj->template->set_vars('attr', $i_attr);
    $obj->template->set_vars('value', $i_value);
} elsif ($i_method eq 'update') {
    if (! defined($i_id)) {PSMT::Error->throw_error_user('attr_invalid_id'); }
    my $i_attr = $obj_cgi->param('attr');
    my $i_old = $obj_cgi->param('old_value');
    my $i_new = $obj_cgi->param('new_value');
    if (! $obj_attr->UpdateAttrForId($i_id, $i_attr, $i_old, $i_new)) {
        PSMT::Error->throw_error_user('attr_update_failed');
    }
    $obj->template->set_vars('attr', $i_attr);
    $obj->template->set_vars('old_value', $i_old);
    $obj->template->set_vars('new_value', $i_new);
} elsif ($i_method eq 'search') {
    my $i_res = $obj_cgi->param('result');
    my $i_attr = $obj_cgi->param('attr');
    my $i_value = $obj_cgi->param('value');
    if (! defined($i_res)) {PSMT::Error->throw_error_user('attr_search_nores'); }
    $i_res = lc($i_res);
    if ($i_res eq 'id') {
        if (defined($i_attr) && defined($i_value)) {
            $obj->template->set_vars('list', $obj_attr->GetIdForPair($i_attr, $i_value));
        } elsif (defined($i_attr)) {
            $obj->template->set_vars('list', $obj_attr->GetIdForAttr($i_attr));
        } else {
            $obj->template->set_vars('list', $obj_attr->GetIdForValue($i_value));
        }
    } elsif ($i_res eq 'value') {
        if (! defined($i_attr)) {PSMT::Error->throw_error_user('attr_search_mis_cond'); }
            $obj->template->set_vars('list', $obj_attr->GetValueForAttr($i_attr));
    } else {
        PSMT::Error->throw_error_user('attr_search_nores');
    }
    $obj->template->set_vars('result', $i_res);
    $obj->template->set_vars('s_attr', $i_attr);
    $obj->template->set_vars('s_value', $i_value);
} else {
    PSMT::Error->throw_error_user('attr_invalid_method');
}

$obj->template->set_vars('id', $i_id);
$obj->template->set_vars('target', $i_target);
# No format specified, default to html
if (! defined(PSMT->cgi()->param('format'))) {
    $obj->template->process('attribute/' . $i_method, 'html');
} else {
    $obj->template->process('attribute/' . $i_method);
}

exit;

