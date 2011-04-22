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
use File::Temp qw/ tempfile /;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;
use PSMT::Label;
use PSMT::Access;

%PSMT::File::EXPORT = qw(
    new

    RegUserAccess

    ListDocsInPath
    ListPathInPath
    ListFilesInDoc
    ListUserLoad
    ListUserLoadForDoc

    ListDavFile

    GetPathInfo

    GetFullPathFromId
    GetIdFromFullPath

    GetDocInfo
    GetDocFiles
    GetDocLastPostFileId
    GetDocLastPostFileInfo

    GetFileInfo
    GetFileSize
    GetFilePath
    GetFileFullPath
    GetFileExt

    RegNewPath
    RegNewDoc
    RegNewFile
    MoveNewFile
    SaveToDav
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
    my $ref = $sth->fetchrow_hashref();
    $ref->{labelid} = PSMT::Label->ListLabelOnDoc($docid);
    $ref->{lastfile} = $self->GetDocLastPostFileInfo($docid);
    return $ref;
}

sub GetDocFiles {
    my ($self, $docid) = @_;
    my @flist;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ?');
    $sth->execute($docid);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        $ref->{size} = $self->GetFileSize($ref->{fileid});
        push(@flist, $ref);
    }
    return \@flist;
}

sub GetDocLastPostFileId {
    my ($self ,$docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? ORDER BY uptime DESC LIMIT 1');
    $sth->execute($docid);
    if ($sth->rows() != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $ref->{fileid};
}

sub GetDocLastPostFileInfo {
    my ($self ,$docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? ORDER BY uptime DESC LIMIT 1');
    $sth->execute($docid);
    if ($sth->rows() != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    $ref->{size} = $self->GetFileSize($ref->{fileid});
    return $ref;
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

sub GetDocidFromFileid {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT docid FROM docinfo WHERE fileid = ?');
    $sth->execute($fileid);
    if ($sth->rows != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $ref->{docid};
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
    my $sth = $dbh->prepare('SELECT docid FROM docreg WHERE pathid = ?');
    $sth->execute($pathid);
    my (@docs, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@docs, $self->GetDocInfo($ref->{docid}));
    }
    return \@docs;
}

sub ListPathInPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT pathid FROM path WHERE parent = ?');
    $sth->execute($pathid);
    my (@path, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@path, $self->GetPathInfo($ref->{pathid}));
    }
    return \@path;
}

sub ListFilesInDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE docid = ? ORDER BY docinfo.uptime DESC');
    $sth->execute($docid);
    my (@files, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@files, $self->GetFileInfo($ref->{fileid}));
    }
    return \@files;
}

sub ListUserLoadForDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT activity.* FROM activity LEFT JOIN docinfo ON activity.fileid = docinfo.fileid WHERE docid = ? ORDER BY activity.dltime DESC');
    my (@dl, $ref);
    $sth->execute($docid);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@dl, $ref);
    }
    return \@dl;
}

sub ListUserLoad {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare('SELECT * FROM activity WHERE fileid = ? ORDER BY dltime DESC');
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
    my $ref = $sth->fetchrow_hashref();
    $ref->{gname} = PSMT::Access->ListPathRestrict($pathid);
    return $ref;
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

sub GetFileSize {
    my ($self, $fileid) = @_;
    my $fname = $self->GetFilePath($fileid) . $fileid;
    return (-s $fname);
}

# fullpath = path_names/doc_name.file_ext
sub GetFileFullPath {
    my ($self, $fileid) = @_;
    my $finfo = $self->GetFileInfo($fileid);
    if (! defined($finfo)) {return undef; }
    my $docinfo = $self->GetDocInfo($finfo->{docid});
    if (! defined($docinfo)) {return undef; }
    my $fname = $self->GetFullPathFromId($docinfo->{pathid});
    $fname .= '/' . $docinfo->{filename} . '.' . $finfo->{fileext};
    return $fname;
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
    if ($sth->execute($pathid, $name, $desc) == 0) {return $docid; }
    $docid = $dbh->db_last_key('docreg', 'docid');
    $dbh->db_unlock_tables();
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

sub RegNewPath {
    my ($self, $cur, $path, $desc, $group) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE');
    my $sth = $dbh->prepare('INSERT INTO path (parent, pathname, description) VALUES (?, ?, ?)');
    if ($sth->execute($cur, $path, $desc) == 0) {return 0; }
    my $pathid = $dbh->db_last_key('path', 'pathid');
    $dbh->db_unlock_tables();
    PSMT::Access->SetPathAccessGroup($pathid, $group);
    return $pathid;
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

sub SaveToDav {
    my ($self, $fh) = @_;
    my ($out, $fname) = tempfile( DIR => PSMT::Config->GetParam('dav_path') );
    my $buf;
    binmode $out;
    while (read($fh, $buf, 1024)) {print $out $buf; }
    close $out;
    return $fname;
}

################################################################## PRIVATE

sub GetHashString {
    my ($self, $string) = @_;
    my $ctx = Digest::MD5->new;
    utf8::encode($string);
    $ctx->add(time() . $string);
    my $hash = $ctx->b64digest;
    $hash =~ s/\+/\_/g;
    $hash =~ s/\//-/g;
    return $hash;
}



1;

__END__


