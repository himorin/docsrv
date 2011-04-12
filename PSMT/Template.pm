# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Template
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Template;

use strict;

use base qw(Exporter);
use Template;

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;
use PSMT::User;

%PSMT::Template::EXPORT = qw(
    new

    process

    set_vars
    vars
);

our $obj_config;
our $conf_template;
our %hash_vars = {};

sub new {
    my ($this) = @_;

    $obj_config = PSMT->config;
    $conf_template = {
        INCLUDE_PATH => PSMT::Constants::LOCATIONS()->{'rel_tmpl'},
        INTERPOLATE  => 1,
        POST_CHOMP   => 0,
        EVAL_PERL    => 1,
        COMPILE_DIR  => PSMT::Constants::LOCATIONS()->{'datacache'},
#        DEBUG => 'parser, undef',
        ENCODING     => 'UTF-8',
        PRE_PROCESS  => 'initialize.none.tmpl',
        FILTERS      => {
            none       => \&PSMT::Util::filter_none,
            js         => \&PSMT::Util::filter_js,
            html_lb    => \&PSMT::Util::filter_html_lb,
            html_nb    => \&PSMT::Util::filter_html_nb,
            html       => \&PSMT::Util::filter_html,
            text       => \&PSMT::Util::filter_text,
            url_quote  => \&PSMT::Util::filter_url_quote,
            ipaddr     => \&PSMT::Util::StrToIpaddr,
        },
        CONSTANTS => _load_constants(),
        VARIABLES => {
            'Param'    => sub { return $obj_config->GetHash(); },
        },
    };

    return $this;
}

sub process {
    my ($this, $template, $ext, $cur_vars, $out) = @_;
    my $obj_template = Template->new($conf_template);
    if (defined($cur_vars)) {
        foreach (keys(%$cur_vars)) {
            PSMT->template->set_vars($_, $cur_vars->{$_});
        }
    }
    $template .= '.' . $ext . '.tmpl';
    $obj_template->process($template, PSMT->template->vars(), $out);
}

sub set_vars {
    my ($self, $name, $value) = @_;
    $hash_vars{$name} = $value;
}

sub vars {
    my ($self) = @_;
    return \%hash_vars;
}

################################################################## PRIVATE

sub _load_constants() {
    my %consts;
    foreach my $item (@PSMT::Constants::EXPORT) {
        if (ref PSMT::Constants->$item) {
            $consts{$item} = PSMT::Constants->$item;
        } else {
            my @list = (PSMT::Constants->$item);
            $consts{$item} = (scalar(@list) == 1) ? $list[0] : \@list;
        }
    }
    return \%consts;
}


1;

__END__


