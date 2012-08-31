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
use PSMT::Email;
use PSMT::HyperEstraier;

%PSMT::File::EXPORT = qw(
    new

    RegUserAccess

    ListDocsInPath
    ListPathInPath
    ListFilesInDoc
    ListUserLoad
    ListUserLoadForDoc
    ListFileInExt

    ListAllPath

    GetPathIdForParent
    GetPathIdForDoc

    ListUserUpForDoc
    IsUserUpForDoc

    ListDavFile

    GetPathInfo

    GetFullPathFromId
    GetIdFromFullPath
    GetIdFromName
    GetIdFromFullName

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
    UpdatePathInfo
    UpdatePathInfo2
    UpdateDocInfo
    UpdateDocInfo2
    UpdateFileInfo
    EditFileAccess

    ValidateNameInPath
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

sub ListFileInExt {
    my ($self, $ext) = @_;
    my @fids;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE fileext = ?');
    $sth->execute($ext);
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@fids, $ref->{fileid});
    }
    return \@fids;
}

sub GetDocInfo {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
    my $sth = $dbh->prepare('SELECT * FROM docreg WHERE docid = ?');
    $sth->execute($docid);
    if ($sth->rows != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    $ref->{gname} = PSMT::Access->ListDocRestrict($docid);
    $ref->{labelid} = PSMT::Label->ListLabelOnDoc($docid);
    $ref->{lastfile} = $self->GetDocLastPostFileInfo($docid);
    return $ref;
}

# by default : For admin all, for non-admin enabled + self-uploaded
# is_all : default (undef) is FALSE, return all if TRUE
sub GetDocFiles {
    my ($self, $docid, $is_all) = @_;
    my @flist;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    if ($is_all) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? ORDER BY uptime DESC');
        $sth->execute($docid);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND (enabled = 1 OR uname = ?) ORDER BY uptime DESC');
        $sth->execute($docid, $uname);
    }
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        $ref->{size} = $self->GetFileSize($ref->{fileid});
        push(@flist, $ref);
    }
    return \@flist;
}

# Always select 'enabeld' one (for user-wide consistency)
sub GetDocLastPostFileId {
    my ($self ,$docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND enabled = 1 ORDER BY uptime DESC LIMIT 1');
    $sth->execute($docid);
    if ($sth->rows() != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $ref->{fileid};
}

# Always select 'enabeld' one (for user-wide consistency)
sub GetDocLastPostFileInfo {
    my ($self ,$docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND enabled = 1 ORDER BY uptime DESC LIMIT 1');
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
    $dbh->db_lock_tables('path READ');
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
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathname = ? AND parent = ?');
    my $ref;
    $path =~ s/\/\//\//g;
    if (substr($path, 0, 1) eq '/') {$path = substr($path, 1); }
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

sub GetIdFromName {
    my ($self, $pid, $name) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
    my $sth = $dbh->prepare("SELECT * FROM docreg WHERE pathid = ? AND filename = ?");
    my $ref;
    $sth->execute($pid, $name);
    if ($sth->rows != 1) {return 0; }
    $ref = $sth->fetchrow_hashref();
    return $ref->{docid};
}

sub GetIdFromFullName {
    my ($self, $name) = @_;
    if ($name !~ /^(.*)\/([^\/]+)$/) {
        return -1;
    }
    my $path = $1;
    my $fname = $2;
    my $pid = $self->GetIdFromFullPath($path);
    return $self->GetIdFromName($pid, $fname);
}

sub GetDocidFromFileid {
    my ($self, $fileid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
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
    $dbh->db_lock_tables('activity WRITE');
    my $sth = $dbh->prepare('INSERT INTO activity (uname, fileid, dltime, srcip) VALUES (?, ?, NOW(), ?)');
    $sth->execute(PSMT->user->get_uid(), $fileid, $srcip);
}

sub ListDocsInPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
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
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT pathid FROM path WHERE parent = ?');
    $sth->execute($pathid);
    my (@path, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@path, $self->GetPathInfo($ref->{pathid}));
    }
    return \@path;
}

# XXX: NOT USED??
# by default : For admin all, for non-admin enabled + self-uploaded
# is_all : default (undef) is FALSE, return all if TRUE
sub ListFilesInDoc {
    my ($self, $docid, $is_all) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    if ($is_all) {
        $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE docid = ? ORDER BY docinfo.uptime DESC');
        $sth->execute($docid);
    } else {
        $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE docid = ? AND (enabled = 1 OR uname = ?) ORDER BY docinfo.uptime DESC');
        $sth->execute($docid, $uname);
    }
    my (@files, $ref);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@files, $self->GetFileInfo($ref->{fileid}, $is_all));
    }
    return \@files;
}

sub ListUserLoadForDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('activity READ, docinfo READ');
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
    $dbh->db_lock_tables('activity READ');
    my $sth = $dbh->prepare('SELECT * FROM activity WHERE fileid = ? ORDER BY dltime DESC');
    my (@dl, $ref);
    $sth->execute($fileid);
    while ($ref = $sth->fetchrow_hashref()) {
        push(@dl, $ref);
    }
    return \@dl;
}

sub ListUserUpForDoc {
    my ($self, $did) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT uname FROM docinfo WHERE docid = ? GROUP BY uname');
    $sth->execute($did);
    return $sth->fetchall_arrayref();
}

sub IsUserUpForDoc {
    my ($self, $did) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT uname FROM docinfo WHERE docid = ? AND uname = ?');
    $sth->execute($did, PSMT->user->get_uid());
    if ($sth->rows() > 0) {return TRUE; }
    return FALSE;
}

# List all path in DB
#   if defined($all), ignore restriction
#   if $all = 1, ignore restriction
sub ListAllPath {
    my ($self, $hash, $all) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT * FROM path ORDER BY pathid ASC');
    $sth->execute();
    if ($sth->rows == 0) {return undef; }
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        if (! PSMT::Access->CheckForPath($ref->{pathid}, FALSE)) {
            if (defined($all)) {$ref->{visible} = FALSE; }
            else {next; }
        } else {
            $ref->{visible} = TRUE;
        }
        if (defined($hash->{$ref->{parent}})) {
            $ref->{fullpath} = $hash->{$ref->{parent}}->{fullpath} . '/';
            $ref->{fullpath} .= $ref->{pathname};
        } else {
            $ref->{fullpath} = $ref->{pathname};
        }
        $hash->{$ref->{pathid}} = $ref;
    }
    return $hash;
}

sub GetPathInfo {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
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
    $dbh->db_lock_tables('docinfo READ');
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

# by default : For admin all, for non-admin enabled + self-uploaded
# is_all : default (undef) is FALSE, return all if TRUE
sub GetFileInfo {
    my ($self, $fileid, $is_all) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    if ($is_all) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE fileid = ?');
        $sth->execute($fileid);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE fileid = ? AND (enabled = 1 OR uname = ?)');
        $sth->execute($fileid, $uname);
    }
    if ($sth->rows != 1) {return undef; }
    return $sth->fetchrow_hashref();
}

sub RegNewDoc {
    my ($self, $pathid, $name, $desc) = @_;
    my $docid = 0;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE, docreg WRITE');
    $self->ValidateNameInPath($pathid, $name);
    my $sth = $dbh->prepare('INSERT INTO docreg (pathid, filename, description) VALUES (?, ?, ?)');
    if ($sth->execute($pathid, $name, $desc) == 0) {return $docid; }
    $docid = $dbh->db_last_key('docreg', 'docid');
    $dbh->db_unlock_tables();
# No Need To Send Mail in 'RegNewDoc' : Always Followed by 'RegNewFile' !
#    PSMT->email()->NewDocInPath($pathid, $docid);
    return $docid;
}

sub RegNewFile {
    my ($self, $ext, $docid, $desc, $is_add) = @_;
    if (! defined($is_add)) {$is_add = TRUE; } # Adding mode
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
    $ext = lc($ext);
    $sth = $dbh->prepare('INSERT INTO docinfo (fileid, fileext, docid, uptime, uname, srcip, description) VALUES (?, ?, ?, NOW(), ?, ?, ?)');
    $sth->execute($fileid, $ext, $docid, $uname, $srcip, $desc);
    $dbh->db_unlock_tables();
    if ($is_add == TRUE) {PSMT->email()->NewFileInDoc($docid, $fileid); }
    else {PSMT->email()->NewDocInPath($docid, $fileid); }
    return $fileid;
}

sub RegNewPath {
    my ($self, $cur, $path, $desc, $group) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE, docreg WRITE');
    $self->ValidateNameInPath($cur, $path);
    my $sth = $dbh->prepare('INSERT INTO path (parent, pathname, description) VALUES (?, ?, ?)');
    if ($sth->execute($cur, $path, $desc) == 0) {return 0; }
    my $pathid = $dbh->db_last_key('path', 'pathid');
    $dbh->db_unlock_tables();
    PSMT::Access->SetPathAccessGroup($pathid, $group);
    PSMT->email()->NewPathInPath($cur, $pathid);
    return $pathid;
}

sub UpdatePathInfo2 {
    my ($self, $pid, $old, $new) = @_;
    my $dbh = PSMT->dbh;
    my $sth;
    my $cur_access = undef;
    if (! PSMT->user->is_inadmin()) {PSMT::Error->throw_error_user('update_permission'); }
    $dbh->db_lock_tables('path WRITE, access_path WRITE');
    my $pathinfo = $self->GetPathInfo($pid);
    if (! defined($pathinfo)) {PSMT::Error->throw_error_user('invalid_path_id'); }
    if ($new->{parent} eq $pid) {PSMT::Error->throw_error_user('invalid_new_path'); }
    # check current match
    if (($pathinfo->{pathname} ne $old->{name}) || 
        ($pathinfo->{description} ne $old->{description}) ||
        ($pathinfo->{parent} ne $old->{parent})) {
        PSMT::Error->throw_error_user('old_not_match');
    }
    # check collision if changing parent or name
    if ($pathinfo->{parent} ne $new->{parent}) {
        $cur_access = PSMT::Access->ListFullPathRestrict($pid);
    }
    if (($pathinfo->{parent} ne $new->{parent}) ||
        ($pathinfo->{pathname} ne $new->{name})) {
        $self->ValidateNameInPath($new->{parent}, $new->{name});
    }
    # update
    $sth = $dbh->prepare(
        'UPDATE path SET parent = ?, pathname = ?, description = ? WHERE pathid = ?');
    if ($sth->execute($new->{parent}, $new->{name}, $new->{description}, $pid) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    # set group restriction if parent path changed
    if (defined($cur_access)) {
        PSMT::Access->SetPathAccessGroup($pid, $cur_access);
    }
    $dbh->db_unlock_tables();
}

sub UpdatePathInfo {
    my ($self, $pid, $name, $desc) = @_;
    my $dbh = PSMT->dbh;
    my $sth;
    my $pathinfo = $self->GetPathInfo($pid);
    if (! defined($pathinfo)) {PSMT::Error->throw_error_user('invalid_path_id'); }
    if (! PSMT->user->is_inadmin()) {PSMT::Error->throw_error_user('update_permission'); }
    $dbh->db_lock_tables('docreg WRITE, path WRITE');
    # collision
    if ($pathinfo->{pathname} ne $name) {
        $self->ValidateNameInPath($pathinfo->{parent}, $name);
    }
    # update
    $sth = $dbh->prepare('UPDATE path SET pathname = ?, description = ? WHERE pathid = ?');
    if ($sth->execute($name, $desc, $pid) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    $dbh->db_unlock_tables();
}

sub UpdateDocInfo {
    my ($self, $did, $name, $desc) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ, docreg WRITE, path WRITE');
    my $sth;
    my $docinfo = $self->GetDocInfo($did);
    if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_document_id'); }
    if (! PSMT->user->is_inadmin()) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE uname = ? AND docid = ?');
        $sth->execute(PSMT->user->get_uid(), $did);
        if ($sth->rows == 0) {PSMT::Error->throw_error_user('update_permission'); }
    }
    # collision
    if ($docinfo->{filename} ne $name) {
        $self->ValidateNameInPath($docinfo->{pathid}, $name);
    }
    # update
    $sth = $dbh->prepare('UPDATE docreg SET filename = ?, description = ? WHERE docid = ?');
    if ($sth->execute($name, $desc, $did) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    $dbh->db_unlock_tables();
}

sub UpdateFileInfo {
    my ($self, $fid, $desc) = @_;
    my $finfo = $self->GetFileInfo($fid);
    if (! defined($finfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }
    if ((! PSMT->user->is_inadmin()) && ($finfo->{uname} ne PSMT->user->get_uid())) {
        PSMT::Error->throw_error_user('update_permission');
    }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo WRITE');
    my $sth = $dbh->prepare('UPDATE docinfo SET description = ? WHERE fileid = ?');
    if ($sth->execute($desc, $fid) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    $dbh->db_unlock_tables();
}

sub EditFileAccess {
    my ($self, $fid, $is_enabled) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo WRITE');
    my $finfo = $self->GetFileInfo($fid);
    if (! defined($finfo)) {PSMT::Error->throw_error_user('update_permission'); }
    if ((! PSMT->user->is_inadmin()) && ($finfo->{uname} ne PSMT->user->get_uid())) {
        PSMT::Error->throw_error_user('update_permission');
    }
    if (! defined($is_enabled)) {$is_enabled = TRUE; }
    my $sth = $dbh->prepare('UPDATE docinfo SET enabled = ? WHERE fileid = ?');
    if ($sth->execute(($is_enabled ? 1 : 0), $fid) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    $dbh->db_unlock_tables();
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
    # Exec HyperEstraier Index
    my $obj = new PSMT::HyperEstraier(TRUE);
    $obj->AddNewFile($fid);
    return TRUE;
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

sub ValidateNameInPath {
    my ($self, $pid, $name) = @_;
    my $errid = '';
    if (! defined($name)) {
        PSMT::Template->set_vars('method', 'File::ValidateNameInPath');
        PSMT::Error->throw_error_code('invalid_parameter');
    }
    # check name itself
    if ($name eq '') {$errid = 'null_name'; }
    my $inv_char = INVALID_NAME_CHAR;
    if ($name =~ /$inv_char/g) {$errid = 'cannot_use_char'; }
    if ($errid ne '') {
        PSMT::Template->set_vars('new_name', $name);
        PSMT::Template->set_vars('error_id', $errid);
        PSMT::Error->throw_error_user('invalid_new_name');
    }
    # check the same in the target path
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ, docreg READ');
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathname = ? AND parent = ?');
    $sth->execute($name, $pid);
    if ($sth->rows() > 0) {$errid = 'path'; }
    $sth = $dbh->prepare('SELECT * FROM docreg WHERE filename = ? AND pathid = ?');
    $sth->execute($name, $pid);
    if ($sth->rows() > 0) {$errid = 'doc'; }
    if ($errid ne '') {
        PSMT::Template->set_vars('new_name', $name);
        PSMT::Template->set_vars('target', $errid);
        PSMT::Template->set_vars('error_id', 'collision');
        PSMT::Error->throw_error_user('invalid_new_name');
    }
}

sub GetPathIdForParent {
    my ($self, $pid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT parent FROM path WHERE pathid = ?');
    $sth->execute($pid);
    if ($sth->rows() == 0) {return -1; }
    return $sth->fetchrow_hashref()->{parent};
}

sub GetPathIdForDoc {
    my ($self, $did) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
    my $sth = $dbh->prepare('SELECT pathid FROM docreg WHERE docid = ?');
    $sth->execute($did);
    if ($sth->rows() == 0) {return -1; }
    return $sth->fetchrow_hashref()->{pathid};
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


