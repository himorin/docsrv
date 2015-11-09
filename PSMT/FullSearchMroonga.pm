# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Mroonga wrapper
#
# Copyright (C) 2015 - : SuMIRe/PFS
# Contributor(s):
#   Atsushi Shimono <atsushi@himor.in>

package PSMT::FullSearchMroonga;

use strict;

use base qw(Exporter);

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;
use PSMT::User;
use PSMT::Error;
use PSMT::Template;
use PSMT::File;
use PSMT::DB;

%PSMT::FullSearchMroonga::EXPORT = qw(
    new
    AddNewFile
    ExecSearch

    GetFileInfo
);

sub new {
    my ($self) = @_;
    return $self;
}

sub ExecSearch {
    my ($self, $phrase) = @_;
    my @fids;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('fullindex READ');
    my $sth = $dbh->prepare('SELECT fileid FROM fullindex WHERE MATCH (content) AGAINST (?)');
    $sth->execute($phrase);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {push(@fids, $ref->{fileid}); }
    return \@fids;
}

sub AddNewFile {
    my ($self, $fid) = @_;
    my $finfo = PSMT::File->GetFileInfo($fid);
    # filter and add
    my $hash_cmd = HE_FILE_FILTER;
    my $cmd = $hash_cmd->{$finfo->{fileext}};
    if (! defined($cmd)) {return; }
    my $fname = PSMT::File->GetFilePath($fid) . $fid;
    if ($cmd eq HE_FILE_FILTER_INTERNAL) {
        $self->_add_text($fid, $self->_parse_format($finfo->{fileext}, $fname));
    } else {
        my $fh;
        # if could not execute, just return without adding
        # XXX shall we call error handler? (also consider command line tool)
        if (index($cmd, '|') != -1) {
            $cmd = "cat $fname | $cmd |";
        } else {
            $cmd = "$cmd $fname - |";
        }
        open($fh, $cmd) or return;
        $self->_add_fh($fid, $fh);
        close($fh);
    }
}

# check whether entry is already exists or not
sub GetFileInfo {
    my ($self, $fid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('fullindex READ');
    my $sth = $dbh->prepare('SELECT fileid FROM fullindex WHERE fileid = ?');
    $sth->execute($fid);
    if ($sth->rows() != 1) {return undef; }
    return PSMT::File->GetFileInfo($fid);
}

#------------------------------------------------------------------------

sub _parse_format {
    my ($self, $ext, $fname) = @_;
    my $text = '';
    my $pkg_module = 'PSMT::FullSearch::' . uc($ext);
    eval ("require $pkg_module") || return "";
    return $pkg_module->DumpText($fname);
}

# add to fulltext index data store, or update if exists
sub _add_text {
    my ($self, $fid, $text) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('fullindex WRITE');
    my $sth = $dbh->prepare('SELECT fileid FROM fullindex WHERE fileid = ?');
    $sth->execute($fid);
    if ($sth->rows() != 1) {
        $sth = $dbh->prepare('INSERT INTO fullindex (content, fileid) VALUES (?, ?)');
    } else {
        $sth = $dbh->prepare('UPDATE fullindex SET content = ? WHERE fileid = ?');
    }
    $sth->execute($text, $fid) == 0;
}

sub _add_fh {
    my ($self, $fid, $fh) = @_;
    my $text;
    foreach (<$fh>) {
        chomp();
        $text .= $_ . ' ';
    }
    return $self->_add_text($fid, $text);
}


1;

__END__


