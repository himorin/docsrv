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
use PSMT::Attribute;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $hash = {};
my $type = $obj_cgi->param('type');
my $iid  = $obj_cgi->param('id');
my $outtm = $type;
my $objattr;

if ($type eq 'allpath') {
    PSMT::File->ListAllPath($hash);
    $outtm = 'table';
} elsif ($type eq 'docsinpath') {
    my $tarr = PSMT::File->ListDocsInPath($iid);
    $outtm = 'table';
    foreach (@$tarr) {
        my $chash = {};
        $chash->{docid} = $_->{docid};
        $chash->{filename} = $_->{filename};
        $chash->{secure} = $_->{secure};
        $hash->{$_->{docid}} = $chash;
    }
} elsif ($type eq 'pathinfo') {
    $hash = PSMT::File->GetPathInfo($iid);
    $hash->{parr} = PSMT::File->GetFullPathArray($iid);
    $objattr = PSMT::Attribute->new();
    $objattr->SetTarget('path');
    $hash->{attr} = $objattr->GetAttrForId($iid);
} elsif ($type eq 'docinfo') {
    $hash = PSMT::File->GetDocInfo($iid);
    $hash->{parr} = PSMT::File->GetFullPathArray($hash->{pathid});
    $hash->{exts} = PSMT::File->ListExtInDoc($iid);
    $objattr = PSMT::Attribute->new();
    $objattr->SetTarget('doc');
    $hash->{attr} = $objattr->GetAttrForId($iid);
    $hash->{lastfile}->{filemime} = PSMT::Util->GetMimeType($hash->{lastfile}->{fileext});
} elsif ($type eq 'loaddoc') {
    $hash = PSMT::File->ListUserLoadForDoc($iid);
} elsif ($type eq 'loadfile') {
    $hash = PSMT::File->ListUserLoad($iid);
} else {PSMT::Error->throw_error_user('invalid_param'); }
if (! defined($hash)) {PSMT::Error->throw_error_user('invalid_param'); }

$obj->template->set_vars('type', $type);
$obj->template->set_vars('outtm', $outtm);
$obj->template->set_vars('id', $iid);
$obj->template->set_vars('jsondata', $hash);

if (! defined(PSMT->cgi()->param('format'))) {
    $obj_cgi->header( -type => "application/json" );
    $obj->template->process('json/' . $outtm, 'json');
} else {
    if (PSMT->cgi()->param('format') eq 'js') {
        $obj->template->process('json/wrap', 'js');
    } else {
        $obj->template->process('json/' . $outtm);
    }
}

exit;

