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
);

sub new {
    my ($self) = @_;
    return $self;
}

sub NewDocInPath {
    my ($self, $docid, $new) = @_;
    my $users = $self->_get_user_for_doc($docid);
    my $obj = new PSMT::Template;
    my $docinfo = PSMT::File->GetDocInfo($docid);
    $obj->set_vars('target', PSMT::File->GetPathInfo($docinfo->{pathid}));
    $obj->set_vars('newdoc', $docinfo);
    $obj->set_vars('newfile', PSMT::File->GetFileInfo($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newdoc'); }
}

sub NewPathInPath {
    my ($self, $pid, $new) = @_;
    my $users = $self->_get_user_for_path($pid);
    my $obj = new PSMT::Template;
    $obj->set_vars('target', PSMT::File->GetPathInfo($pid));
    $obj->set_vars('newpath', PSMT::File->GetPathInfo($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($pid));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newpath'); }
}

sub NewFileInDoc {
    my ($self, $did, $new) = @_;
    my $users = $self->_get_user_for_doc($did);
    my $obj = new PSMT::Template;
    my $docinfo = PSMT::File->GetDocInfo($did);
    $obj->set_vars('target', $docinfo);
    $obj->set_vars('newfile', PSMT::File->GetFileInfo($new));
    $obj->set_vars('filesize', PSMT::File->GetFileSize($new));
    $obj->set_vars('path', PSMT::File->GetFullPathFromId($docinfo->{pathid}));
    foreach (keys %$users) {$self->_send_email($obj, $_, 'newfile'); }
}



#------------------------------------------------------------------------

sub _send_email {
    my ($self, $obj, $uname, $tmpl) = @_;
    my $out;
    my %ref;
    $ref{uname} = $uname;
    $ref{by} = PSMT->user()->get_uid();
    $ref{emailto} = PSMT->ldap()->GetAttrsFromUID($uname, 'mail')->{bugmail}[0];
    $obj->process('email/' . $tmpl, 'email', \%ref, \$out);
    my @args;
    push(@args, '-i');
    push(@args, '-fmaint@psmt.kusastro.kyoto-u.ac.jp');
    push(@args, '-ODeliveryMode=deferred');
    # XXX: this line is for quick hack
    while ($out =~ s/^[\r\n]//g) {}
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


#    my $dbh = PSMT->dbh;
#    my $sth = $dbh->prepare('SELECT * FROM setting');
#    $sth->execute();
#    my $ref;
#    while ($ref = $sth->fetchrow_hashref()) {

#    if ($sth->rows != 1) {return undef; }
#    my $uname = PSMT->user->get_uid();
#    $dbh->db_lock_tables('docreg WRITE, path WRITE');
#    $dbh->db_unlock_tables();



1;

__END__


