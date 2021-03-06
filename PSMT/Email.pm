# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Mail publisher
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Email;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;
use PSMT::Label;
use PSMT::Access;
use PSMT::File;
use PSMT::User;
use PSMT::UserConfig;
use PSMT::Template;

use Email::Send;

%PSMT::Email::EXPORT = qw(
    new

    NewDocInPath
    NewPathInPath
    NewFileInDoc

    SendPassword
);

sub new {
    my ($self) = @_;
    return $self;
}

sub NewDocInPath {
    my ($self, $docid, $new, $daddrs) = @_;
    my $users = $self->_get_user_for_doc($docid);
    my $obj = new PSMT::Template;
    my $docinfo = PSMT::File->GetDocInfo($docid);
    $obj->set_vars('target', PSMT::File->GetPathInfo($docinfo->{pathid}));
    $obj->set_vars('newdoc', $docinfo);
    $obj->set_vars('newfile', PSMT::File->GetFileInfo($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newdoc'); }
    if (defined($daddrs) && ($daddrs ne "")) {
        my @addrs = split(/,/, $daddrs);
        foreach (@addrs) {$self->_send_email($obj, $_, 'newdoc', TRUE); }
    }
}

sub NewPathInPath {
    my ($self, $pid, $new, $daddrs) = @_;
    my $users = $self->_get_user_for_path($pid);
    my $obj = new PSMT::Template;
    $obj->set_vars('target', PSMT::File->GetPathInfo($pid));
    $obj->set_vars('newpath', PSMT::File->GetPathInfo($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($pid));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newpath'); }
    if (defined($daddrs) && ($daddrs ne "")) {
        my @addrs = split(/,/, $daddrs);
        foreach (@addrs) {$self->_send_email($obj, $_, 'newpath', TRUE); }
    }
}

sub NewFileInDoc {
    my ($self, $did, $new, $daddrs) = @_;
    my $users = $self->_get_user_for_doc($did);
    my $obj = new PSMT::Template;
    my $docinfo = PSMT::File->GetDocInfo($did);
    $obj->set_vars('target', $docinfo);
    $obj->set_vars('newfile', PSMT::File->GetFileInfo($new));
    $obj->set_vars('filesize', PSMT::File->GetFileSize($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newfile'); }
    if (defined($daddrs) && ($daddrs ne "")) {
        my @addrs = split(/,/, $daddrs);
        foreach (@addrs) {$self->_send_email($obj, $_, 'newfile', TRUE); }
    }
}

sub SendPassword {
    my ($self, $dname, $uid, $pass) = @_;
    my $obj = new PSMT::Template;
    $obj->set_vars('uid', $uid);
    $obj->set_vars('fname', $dname);
    $obj->set_vars('pass', $pass);
    $self->_send_email($obj, $uid, 'pass');
}


#------------------------------------------------------------------------

sub _send_email {
    my ($self, $obj, $uname, $tmpl, $is_direct) = @_;
    my $out;
    my %ref;
    $obj->update_lang('email');
    $ref{uname} = $uname;
    $ref{by} = PSMT->user()->get_uid();
    if (defined($is_direct)) {
        $ref{emailto} = $uname;
        $ref{ispush} = TRUE;
    } else {
        $ref{emailto} = PSMT->ldap()->GetAttrsFromUID($uname, 'mail')->{mail}[0];
    }
    $obj->process('email/' . $tmpl, 'email', \%ref, \$out);
    my @args;
    push(@args, '-i');
    push(@args, '-f' . PSMT->config->GetParam('admin_email'));
    push(@args, '-ODeliveryMode=deferred');
    # XXX: this line is for quick hack
    while ($out =~ s/^[\r\n]//g) {}
    # header tweak
    my $mailer = Email::Send->new({ mailer => 'Sendmail', mailer_args => \@args});
    my $retval = $mailer->send($out);
}

sub _get_user_for_doc {
    my ($self, $did) = @_;
    my %hash;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM favorite WHERE docid = ?');
    $sth->execute();
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        $hash{$ref->{uname}} = $ref->{docid};
    }
    my $pid = PSMT::File->GetPathIdForDoc($did);
    while ($pid != 0) {                                                         
        $self->_merge_fav_path($pid, \%hash);
        $pid = PSMT::File->GetPathIdForParent($pid);
    }
    return \%hash;
}

sub _get_user_for_path {
    my ($self, $pid) = @_;
    my %hash;
    while ($pid != 0) {                                                         
        $self->_merge_fav_path($pid, \%hash);
        $pid = PSMT::File->GetPathIdForParent($pid);
    }
    return \%hash;
}

sub _merge_fav_path {
    my ($self, $pid, $hash) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM fav_path WHERE pathid = ?');
    $sth->execute($pid);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        if (! defined($hash->{$ref->{uname}})) {
            $hash->{$ref->{uname}} = 'p' . $ref->{pathid};
        }
    }
    return $hash;
}



1;

__END__


