#! /usr/bin/perl

use strict;
use lib '.';
use PSMT;

use JSON;

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
    $hash = PSMT::File->ListDocsInPath($iid);
    $outtm = 'table';
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
} elsif ($type eq 'loaddoc') {
    $hash = PSMT::File->ListUserLoadForDoc($iid);
    FilterIP($hash);
} elsif ($type eq 'loadfile') {
    $hash = PSMT::File->ListUserLoadForFile($iid);
    FilterIP($hash);
} else {PSMT::Error->throw_error_user('invalid_param'); }
if (! defined($hash)) {PSMT::Error->throw_error_user('invalid_param'); }

$obj->template->set_vars('type', $type);
$obj->template->set_vars('outtm', $outtm);
$obj->template->set_vars('id', $iid);
$obj->template->set_vars('jsondata', $hash);

if ( (! defined(PSMT->cgi()->param('format'))) ||
     (PSMT->cgi()->param('format') eq 'json') ) {
    print $obj_cgi->header( -type => "application/json" );
    print "\n";
    print MakeJson();
} else {
    if (PSMT->cgi()->param('format') eq 'js') {
        print $obj_cgi->header( -type => "application/javascript" );
        print "\n";
        print "var conf_data_$type = ";
        print MakeJson();
        print ";";
    } else {
        $obj->template->process('json/' . $outtm);
    }
}

exit;

sub MakeJson {
    my $json;
    $json = to_json( { 'type' => $type, 'data' => $hash } );
    return $json;
}

sub FilterIP {
    my ($arr) = @_;
    foreach (0 ... $#$arr) {
        $arr->[$_]->{srcip} = PSMT::Util::StrToIpaddr($arr->[$_]->{srcip});
    }
}

