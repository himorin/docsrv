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
use File::Path;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;

%PSMT::File::EXPORT = qw(
    new

    UserCanAccessDoc
    UserCanAccessPath
    RegUserAccess

    ListDocsInPath
    ListPathInPath
    ListFilesInDoc
    ListUserLoad

    ListDavFile

    GetPathInfo
    GetPathAccessGroup
    SetPathAccessGroup

    GetFullPathFromId
    GetIdFromFullPath

    GetDocInfo
    GetDocFiles
    GetDocAccessGroup

    GetFileInfo
    GetFilePath
    GetFileExt

    RegNewDoc
    RegNewFile
    MoveNewFile
);

my $hash_each = 2;

sub new {
    my ($self) = @_;
    return $self;
}

sub ListDavFile {
    my ($self) = @_;
    my $path;
    if (($path = PSMT::Config->GetParam('dav_path')) eq '') {return undef; }
    my %files;
    opendir(INDIR, $path);
    my $fname;
    foreach (readdir(INDIR)) {
        $fname = $path . '/' . $_;
        if ((-f $fname) && (-s $fname > 0)) {$files{$_} = -s $fname; }
    }
    closedir(INDIR);
    return \%files;
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
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ?');
    $sth->execute($docid);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@flist, $ref);
    }
    return \@flist;
}

sub GetFullPathFromId {
    my ($self, $pid) = @_;
    my $path;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathid = ?');
    my $ref;
    while ($pid != 0) {
        $sth->execute($pid);
        if ($sth->rows != 1) {return undef; }
        $ref = $sth->fetchrow_hashref();
        $pid = $ref->{parent};
        $path = $ref->{pathname} . '/' . $path;
    }
    return $path;
}

sub GetIdFromFullPath {
    my ($self, $path) = @_;
    my $pid = 0;
    my $cdir;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathname = ? AND parent = ?');
    my $ref;
    my @dirs = split(/\//, $path);
    while ($#dirs > -1) {
        $cdir = shift(@dirs);
        $sth->execute($cdir, $pid);
        if ($sth->rows != 1) {return 0; }
        $ref = $sth->fetchrow_hashref();
        $pid = $ref->{pathid};
    }
    return $pid;
}

sub GetDocAccessGroup {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT access_path.gname AS gname FROM access_path LEFT JOIN docreg ON access_path.pathid = docreg.pathid WHERE docreg.docid = ?');
    $sth->execute($docid);
    my ($ref, %glist);
    while ($ref = $sth->fetchrow_hashref()) {
        $glist{$ref->{gname}} = $ref;
    }
    return \%glist;
}

sub GetPathAccessGroup {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    $sth->execute($pathid);
    my ($ref, %glist);
    while ($ref = $sth->fetchrow_hashref()) {
        $glist{$ref->{gname}} = $ref;
    }
    return \%glist;
}

sub SetPathAccessGroup {
    my ($self, $pathid, $group) = @_;
    my $dbh = PSMT->dbh;
    my %gconf;
    foreach (@{PSMT->ldap->GetAvailGroups}) {$gconf{$_} = 0; }
    # check group valid (via ldap)
    foreach (@$group) {$gconf{$_} = 1; }
    # check current
    my $sth = $dbh->prepare('SELECT gname FROM access_path WHERE pathid = ?');
    my $ref;
    $sth->execute($pathid);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($gconf{$ref->{gname}})) {
            if ($gconf{$ref->{gname}} == 0) {$gconf{$ref->{gname}} = 2; }
            else {$gconf{$ref->{gname}} = 0; }
        }
    }
    # update
    foreach (keys %gconf) {
        if ($gconf{$_} == 1) {
            $sth = $dbh->prepare('INSERT access_path (pathid, gname) VALUES (?, ?)');
            $sth->execute($pathid, $_);
        } elsif ($gconf{$_} == 2) {
            $sth = $dbh->prepare('DELETE FROM access_path WHERE pathid = ? AND gname = ?');
            $sth->execute($pathid, $_);
        }
    }
    return TRUE;
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

sub RegNewDoc {
    my ($self, $pathid, $name, $desc) = @_;
    my $docid = 0;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg WRITE');
    my $sth = $dbh->prepare('INSERT INTO docreg (pathid, filename, description) VALUES (?, ?, ?)');
    $sth->execute($pathid, $name, $desc);
    $dbh->db_unlock_tables();
    $docid = $dbh->db_last_key('docreg', 'docid');
    return $docid;
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

sub MoveNewFile {
    my ($self, $src, $fid) = @_;
    my $newpath = $self->GetFilePath($fid);
    eval {
        File::Path::mkpath($newpath);
    };
    if ($@) {
        PSMT::Error->throw_error_user('file_move_failed');
    }
    rename($src, $newpath . $fid);
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


