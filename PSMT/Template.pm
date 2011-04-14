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
use PSMT::Label;
use PSMT::NetLdap;
use PSMT::Error;

%PSMT::Template::EXPORT = qw(
    new

    process

    add_avail_format
    set_vars
    vars
);

our $obj_config;
our $conf_template;
our %hash_vars = {};
our %avail_format;
our $def_format;

sub new {
    my ($this) = @_;

    $def_format = undef;
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
            'User'     => PSMT->user()->user_data(),
            'Group'    => PSMT->ldap()->GetAvailGroups(),
            'Label'    => PSMT::Label->ListAllLabel(),
            'InList'   => sub {
                my ($list, $value) = @_;
                foreach (@$list) {if ($value eq $_) {return TRUE; } }
                return FALSE;
            },
        },
    };

    return $this;
}

sub process {
    my ($this, $template, $ext, $cur_vars, $out) = @_;
    my $obj_template = Template->new($conf_template);
    # Pre appended values (global)
    $this->set_vars('def_label', PSMT::Label->ListAllLabel());
    $this->set_vars('def_group', PSMT->ldap->GetAvailGroups());
    # Append via method
    my @linklist = PSMT::Constants::HEADER_LINKS;
    if (defined($cur_vars->{non_urls})) {
        my %ref;
        foreach (@linklist) {$ref{$_} = 0; }
        foreach (@{$cur_vars->{non_urls}}) {delete($ref{$_}); }
        $this->set_vars('header_links', keys %ref);
        delete($cur_vars->{non_urls});
    } else {
        $this->set_vars('header_links', \@linklist);
    }
    if (defined($cur_vars)) {
        foreach (keys(%$cur_vars)) {
            PSMT->template->set_vars($_, $cur_vars->{$_});
        }
    }
    my $formats = AVAIL_FORMATS;
    if (defined($formats->{$template})) {
        $this->add_avail_format(@{$formats->{$template}});
    }
    if ((! defined($ext)) || ($ext eq '')) {
        $ext = PSMT->cgi()->param('format');
        if (! defined($ext)) {$ext = $def_format; }
    }
    if (! defined($avail_format{$ext})) {
        PSMT::Error->throw_error_code('template_format_missing');
    }
    $template .= '.' . $ext . '.tmpl';
    if (! defined($out)) {print PSMT->cgi()->header(); }
    $obj_template->process($template, PSMT->template->vars(), $out);
}

sub add_avail_format {
    my ($self, @format) = @_;
    if (! defined($def_format)) {$def_format = $format[0]; }
    foreach (@format) {
        if (! defined($avail_format{$_})) {$avail_format{$_} = 1; }
    }
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


