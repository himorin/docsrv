# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - File manipulation
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::File;

use strict;

use Digest::MD5;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::NetLdap;
use PSMT::Util;

%PSMT::File::EXPORT = qw(
    new

    UserCanAccessDoc
    UserCanAccessPath
    RegUserAccess

    ListDocsInPath
    ListPathInPath
    ListFilesInDoc
    ListPath
    ListUserLoad

    GetPathInfo
    GetPathAccessGroup

    GetDocInfo
    GetDocFiles
    GetDocAccessGroup

    GetFileInfo
    GetFilePath
    RegNewFile
    GetFileExt
);

my $hash_each = 2;

sub new {
    my ($self) = @_;
    return $self;
}

sub GetDocInfo {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docreg WHERE docid = ?');
    $sth->execute($docid);
    if ($sth->rows != 1) {return undef; }
    return $sth->fetchrow_hashref();
}

sub GetDocFiles {
    my ($self, $docid) = @_;
    my @flist;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE docid = ?');
    $sth->execute($docid);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@flist, $ref->{fileid});
    }
    return \@flist;
}

sub GetDocAccessGroup {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT access_path.gname AS gname FROM access_path LEFT JOIN docreg ON access_path.pathid = docreg.pathid WHERE docreg.docid = ?');
    $sth->execute($docid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@glist, $ref->{gname});
    }
    return \@glist;
}

sub GetPathAccessGroup {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    $sth->execute($pathid);
    my ($ref, @glist);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@glist, $ref->{gname});
    }
    return \@glist;
}

sub GetDocidFromFileid {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT docid FROM docinfo WHERE fileid = ?');
    $sth->execute($fileid);
    if ($sth->rows != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $ref->{docid};
}

sub UserCanAccessDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT access_path.gname AS gname FROM access_path LEFT JOIN docreg ON docreg.pathid = access_path.pathid WHERE docreg.docid = ?');
    $sth->execute($docid);
    my $ref;
    if ($sth->rows == 0) {
        # if access restriction is NULL, public
        return TRUE;
    }
    while ($ref = $sth->fetchrow_hashref()) {
        if (PSMT->user()->is_ingroup($ref->{'gname'}) == TRUE) {
            return TRUE;
        }
    }
    return FALSE;
}

sub UserCanAccessPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    $sth->execute($pathid);
    my $ref;
    if ($sth->rows == 0) {
        # if access restriction is NULL, public
        return TRUE;
    }
    while ($ref = $sth->fetchrow_hashref()) {
        if (PSMT->user()->is_ingroup($ref->{'gname'}) == TRUE) {
            return TRUE;
        }
    }
    return FALSE;
}

sub RegUserAccess {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $srcip = PSMT::Util::IpAddr();
    my $sth = $dbh->prepare('INSERT INTO activity (uname, fileid, dltime, srcip) VALUES (?, ?, NOW(), ?)');
    $sth->execute(PSMT->user->get_uid(), $fileid, $srcip);
}

sub ListDocsInPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docreg WHERE pathid = ?');
    $sth->execute($pathid);
    my (@docs, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@docs, $ref);
    }
    return \@docs;
}

sub ListPathInPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM path WHERE parent = ?');
    $sth->execute($pathid);
    my (@path, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@path, $ref);
    }
    return \@path;
}

sub ListFilesInDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ?');
    $sth->execute($docid);
    my (@files, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@files, $ref);
    }
    return \@files;
}

sub ListUserLoad {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT uname, dltime, srcip FROM activity WHERE fileid = ?');
    my (@dl, $ref);
    $sth->execute($fileid);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@dl, $ref);
    }
    return \@dl;
}

sub GetPathInfo {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathid = ?');
    $sth->execute($pathid);
    if ($sth->rows != 1) {return undef; }
    return $sth->fetchrow_hashref();
}

# NOT filename BUT "PATH"
sub GetFilePath {
    my ($self, $fileid) = @_;
    my $path = PSMT::Config->GetParam('file_path') . '/';
    my $hashdep = PSMT::Config->GetParam('hash_depth');
    my $fhash = $fileid;
    while ($hashdep > 0) {
        $path .= substr($fhash, 0, $hash_each) . '/';
        $fhash = substr($fhash, $hash_each);
        if (length($fhash) < $hash_each) {return $path; }
        $hashdep -= 1;
    }
    return $path;
}

sub GetFileExt {
    my ($self, $fileid) = @_;
    my $ext = 'default';
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT fileext FROM docinfo WHERE fileid = ?');
    $sth->execute($fileid);
    if ($sth->rows == 1) {
        my $ref = $sth->fetchrow_hashref();
        $ext = $ref->{'fileext'};
    }
    if (defined(contenttypes->{$ext})) {
        return contenttypes->{$ext};
    }
    return 'application/octet-stream';
}

sub GetFileInfo {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE fileid = ?');
    $sth->execute($fileid);
    if ($sth->rows != 1) {return undef; }
    return $sth->fetchrow_hashref();
}

sub RegNewFile {
    my ($self, $ext, $docid, $desc) = @_;
    my $fileid = undef;
    my $uname = PSMT->user()->get_uid();
    my $srcip = PSMT::Util->IpAddr();
    my $hashcnt = 0;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo WRITE');
    my $sth;
    while (! defined($fileid)) {
        $fileid = $self->GetHashString($docid . $uname . $srcip . $desc . $hashcnt);
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE fileid = ?');
        $sth->execute($fileid);
        if ($sth->rows != 0) {
            $fileid = undef;
            $hashcnt += 1;
            if ($hashcnt > 20) {return undef; }
        }
    }
    $sth = $dbh->prepare('INSERT INTO docinfo (fileid, fileext, docid, uptime, uname, srcip, description) VALUES (?, ?, ?, NOW(), ?, ?, ?)');
    $sth->execute($fileid, $ext, $docid, $uname, $srcip, $desc);
    $dbh->db_unlock_tables();
    return $fileid;
}


################################################################## PRIVATE

sub GetHashString {
    my ($self, $string) = @_;
    my $ctx = Digest::MD5->new;
    $ctx->add(time() . $string);
    my $hash = $ctx->b64digest;
    $hash =~ s/\+/\_/g;
    $hash =~ s/\//-/g;
    return $hash;
}



1;

__END__


