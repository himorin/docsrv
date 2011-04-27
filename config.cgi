#! /usr/bin/perl

use strict;
use PSMT;

use PSMT::Constants;
use PSMT::Template;
use PSMT::Config;
use PSMT::CGI;
use PSMT::DB;
use PSMT::User;
use PSMT::UserConfig;
use PSMT::Util;

my $obj = new PSMT;
my $obj_cgi = new PSMT->cgi;

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

# for update
my ($cname, $cinput, $creset);
if ($obj_cgi->request_method() eq 'POST') {
    my $conf = PSMT->user_config->Config();
    foreach (keys %$conf) {
        $cname = $_;
        $cinput = $obj_cgi->param($cname . '_input');
        $creset = $obj_cgi->param($cname . '_default');
        if (defined($creset)) {PSMT->user_config->ParamReset($cname); }
        else {
            if ($conf->{$cname}->{class} eq 'bool') {
                if ($cinput eq 'on') {$cinput = 1; } else {$cinput = 0; }
            }
            if (! defined($cinput)) {next; }
            if ($conf->{$cname}->{is_default} == TRUE) {
                PSMT->user_config->ParamUpdate($cname, $cinput);
            }
            if ($cinput ne $conf->{$cname}->{value}) {
                # exec update
                PSMT->user_config->ParamUpdate($cname, $cinput);
            }
        }
    }
    PSMT->user_config->ConfigReload();
}

# must reload user config before display;
$obj->template->set_vars('config_user', PSMT->user_config->Config());
$obj->template->process('config');


exit;

