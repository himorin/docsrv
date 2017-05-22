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
use Digest::SHA;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use POSIX qw(:math_h);

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;
use PSMT::Label;
use PSMT::Access;
use PSMT::Email;
use PSMT::FullSearchMroonga;

%PSMT::File::EXPORT = qw(
    new

    RegUserAccess

    ListDocsInPath
    ListPathInPath
    ListPathIdInPath
    ListExtInDoc
    ListUserLoad
    ListUserLoadForDoc
    ListFileInExt

    ListAllPath
    ListNullPath
    ListFileNoHash
    AddFileHash
    CheckFileHash
    CheckDavHash
    ListFileHashDup

    SearchPath
    SearchDocFile

    GetPathIdForParent
    GetPathIdForDoc
    CheckPathIdInParent

    CheckPathExist
    CheckDocExist
    DeleteEmptyPath

    ListUserUpForDoc
    IsUserUpForDoc

    ListDavFile

    HashFileToDoc

    GetPathInfo

    GetFullPathFromId
    GetFullPathArray
    GetIdFromFullPath
    GetIdFromName
    GetIdFromFullName

    GetDocInfo
    GetDocsInfo
    ListFilesInDoc
    ListFilesInDocByExt
    GetDocLastPostFileId
    GetDocLastPostFileInfo

    GetFileInfo
    GetFilesInfo
    GetFileSize
    GetFilePath
    GetFileFullPath
    GetFileExt
    GetFileInfoInDocs

    RegNewPath
    RegNewDoc
    RegNewFile
    RegNewFileTime
    UpdatePathInfo
    UpdateDocInfo
    UpdateFileDesc
    UpdateFileVersion
    EditFileAccess

    ValidateNameInPath
    MoveNewFile
    SaveToDav
    MakeEncZipFile
    CheckMimeIsView

    GetNextVersionForDoc
);

my $hash_each = 2;
my $bin_zip = '/usr/bin/zip';

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
    $ref = PSMT::Util->AddShortDesc($ref);
    $ref->{gname} = PSMT::Access->ListDocRestrict($docid);
    $ref->{labelid} = PSMT::Label->ListLabelOnDoc($docid);
    $ref->{lastfile} = $self->GetDocLastPostFileInfo($docid);
    return $ref;
}

# GetDocsInfo($docid)
#   Return hash of hash reference, with document information (basic, shortdesc,
#   restriction, label). No doc->file information.
#   Omit unaccessible documents.
sub GetDocsInfo {
    my ($self, $docid) = @_;
    if (! defined($docid)) {return undef; }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
    my $stmp = '(' . ('?, ' x $#$docid) . '?)';
    my $sth = $dbh->prepare('SELECT * FROM docreg WHERE docid IN ' . $stmp);
    $sth->execute(@$docid);
    my %ret;
    while ((my $ref = $sth->fetchrow_hashref())) {
        if (! PSMT::Access->CheckForDoc($ref->{docid})) {next; }
        $ref = PSMT::Util->AddShortDesc($ref);
        $ref->{gname} = PSMT::Access->ListDocRestrict($ref->{docid});
        $ref->{labelid} = PSMT::Label->ListLabelOnDoc($ref->{docid});
        $ret{$ref->{docid}} = $ref;
    }
    # name
    my %pathname;
    foreach (keys %ret) {
        if (! defined($pathname{$ret{$_}->{pathid}})) {
            $pathname{$ret{$_}->{pathid}}
                = PSMT::File->GetFullPathFromId($ret{$_}->{pathid});
        }
        $ret{$_}->{fullname} = $pathname{$ret{$_}->{pathid}} 
            . $ret{$_}->{filename};
    }
    return \%ret;
}

sub HashFileToDoc {
    my ($self, $fid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $stmp = '(' . ('?, ' x $#$fid) . '?)';
    my $sth = $dbh->prepare('SELECT docid, fileid FROM docinfo WHERE fileid IN ' . $stmp);
    $sth->execute(@$fid);
    if ($sth->rows() == 0) {return undef; }
    my %hash;
    while ((my $ref = $sth->fetchrow_hashref())) {
        $hash{$ref->{fileid}} = $ref->{docid};
    }
    return \%hash;
}

# by default : For admin all, for non-admin enabled + self-uploaded
# is_all : default (undef) is FALSE, return all if TRUE
sub ListFilesInDoc {
    my ($self, $docid, $is_all) = @_;
    my @flist;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    if ($is_all) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? ORDER BY version DESC, uptime DESC');
        $sth->execute($docid);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND (enabled = 1 OR uname = ?) ORDER BY version DESC, uptime DESC');
        $sth->execute($docid, $uname);
    }
    my $ref;
    while ($ref = $sth->fetchrow_hashref()) {
        push(@flist, $self->_attach_file_info($ref));
    }
    return \@flist;
}

# by default : For admin all, for non-admin enabled + self-uploaded
# is_all : default (undef) is FALSE, return all if TRUE
sub ListFilesInDocByExt {
    my ($self, $docid, $ext, $is_all) = @_;
    my @flist;
    if ((! defined($ext)) || ($ext eq '')) {return undef; }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    if ($is_all) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND fileext = ? ORDER BY version DESC, uptime DESC');
        $sth->execute($docid, $ext);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND fileext = ? AND (enabled = 1 OR uname = ?) ORDER BY version DESC, uptime DESC');
        $sth->execute($docid, $ext, $uname);
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
    my ($self, $docid, $ext) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    if (defined($ext)) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND enabled = 1 AND fileext = ? ORDER BY version DESC, uptime DESC LIMIT 1');
        $sth->execute($docid, $ext);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND enabled = 1 ORDER BY version DESC, uptime DESC LIMIT 1');
        $sth->execute($docid);
    }
    if ($sth->rows() != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $ref->{fileid};
}

# Always select 'enabeld' one (for user-wide consistency)
sub GetDocLastPostFileInfo {
    my ($self ,$docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid = ? AND enabled = 1 ORDER BY version DESC, uptime DESC LIMIT 1');
    $sth->execute($docid);
    if ($sth->rows() != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    return $self->_attach_file_info($ref);
}

sub GetFullPathArray {
    my ($self, $pid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathid = ?');
    my $ref;
    my %path;
    while ($pid != 0) {
        $sth->execute($pid);
        if ($sth->rows != 1) {return undef; }
        $ref = $sth->fetchrow_hashref();
        $pid = $ref->{parent};
        $path{$pid} = $ref;
    }
    return \%path;
}

# return path name starts without "/"
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

sub ListPathIdInPath {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT pathid FROM path WHERE parent = ?');
    $sth->execute($pathid);
    my (@path, $ref);
    while ($ref = $sth->fetchrow_hashref()) {push(@path, $ref->{pathid}); }
    return \@path;
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

# GetFileInfoInDocs(\@docid, $is_all)
#   Return array of hash reference, file information (basic).
#   Lists files registered in a document. all files for admin, enabled + self 
#   uploaded for non-admin. 
#   If is_all is set and is TRUE, return all
#   Note, no group restriction to file.
sub GetFileInfoInDocs {
    my ($self, $docid, $is_all) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    if (! defined($is_all)) {$is_all = FALSE; }
    my $uname = PSMT->user->get_uid();
    if (PSMT->user->is_inadmin()) {$is_all = TRUE; }
    my $stmp = '(' . ('?, ' x $#$docid) . '?)';
    my $sth;
    # XXX "ORDER BY docinfo.uptime DESC" is for later listing, remove if no need
    if ($is_all) {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid IN ' . $stmp . 
               ' ORDER BY docinfo.version DESC, docinfo.uptime DESC');
        $sth->execute(@$docid);
    } else {
        $sth = $dbh->prepare('SELECT * FROM docinfo WHERE docid IN ' . $stmp . 
               ' AND (enabled = 1 OR uname = ?)'. 
               ' ORDER BY docinfo.version DESC, docinfo.uptime DESC');
        $sth->execute(@$docid, $uname);
    }

    my (%docs, $files, $ref);  # doc->{docid}->{fileid}
    while ($ref = $sth->fetchrow_hashref()) {
        if (! defined($docs{$ref->{docid}})) {
            $files = ();
            $docs{$ref->{docid}} = $files;
        } else {
            $files = $docs{$ref->{docid}};
        }
        $ref->{size} = $self->GetFileSize($ref->{fileid});
        push(@$files, $ref);
        $docs{$ref->{docid}} = $files;
    }
    return \%docs;
}

sub ListExtInDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    $sth = $dbh->prepare('SELECT fileext FROM docinfo WHERE docid = ? AND enabled = 1 GROUP BY fileext');
    $sth->execute($docid);
    my @exts;
    while (my $ref = $sth->fetchrow_hashref()) {push(@exts, $ref->{fileext}); }
    return \@exts;
}

sub ListUserLoadForDoc {
    my ($self, $docid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('activity READ', 'docinfo READ');
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
#   returned "path" names start with "/"
sub ListAllPath {
    my ($self, $hash, $all) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT * FROM path ORDER BY pathid ASC');
    $sth->execute();
    if ($sth->rows == 0) {return undef; }
    my $ref;
    my $unfp = 0;
    while ($ref = $sth->fetchrow_hashref()) {
        if (! PSMT::Access->CheckForPath($ref->{pathid}, FALSE)) {
            if (defined($all)) {$ref->{visible} = FALSE; }
            else {next; }
        } else {
            $ref->{visible} = TRUE;
        }
        # only if parent is already defined, build fullpath
        if ($ref->{parent} eq 0) {
            $ref->{fullpath} = '/' . $ref->{pathname};
        } elsif (defined($hash->{$ref->{parent}}) &&
            defined($hash->{$ref->{parent}}->{fullpath})) {
            $ref->{fullpath} = $hash->{$ref->{parent}}->{fullpath} . '/';
            $ref->{fullpath} .= $ref->{pathname};
        } else {
            $unfp += 1;
        }
        $hash->{$ref->{pathid}} = $ref;
    }
    # build fullpath tree
    while ($unfp > 0) {
        foreach (keys %$hash) {
            $ref = $hash->{$_};
            if (defined($ref->{fullpath})) {next; }
            if (defined($hash->{$ref->{parent}}) &&
                defined($hash->{$ref->{parent}}->{fullpath})) {
                $ref->{fullpath} = $hash->{$ref->{parent}}->{fullpath} . '/';
                $ref->{fullpath} .= $ref->{pathname};
                $unfp -= 1;
            }
        }
    }
    return $hash;
}

# list path with no file nor subpath
sub ListNullPath {
    my ($self) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ', 'docreg READ');
# NOT WORKING WITH WARNING "Table 'path' was not locked with LOCK TABLES"
#    my $sth = $dbh->prepare(
#        qq {    SELECT pathid, pathnum, docnum
#                  FROM (
#                SELECT pathdoc.pathid, pathdoc.docnum,
#                       count(path.pathid) AS pathnum
#                  FROM (
#                SELECT path.pathid, count(docreg.pathid) AS docnum
#                  FROM path
#       LEFT OUTER JOIN docreg
#                    ON path.pathid = docreg.pathid 
#              GROUP BY path.pathid)
#                    AS pathdoc
#       LEFT OUTER JOIN path
#                    ON pathdoc.pathid = path.parent
#              GROUP BY path.pathid )
#                    AS pdnum
#                 WHERE pathnum = 0 AND docnum = 0
#           });
    # document count
    my $sth = $dbh->prepare(
        qq{    SELECT pathid, entries
                 FROM (
               SELECT path.pathid, COUNT(docreg.pathid) AS entries
                 FROM path
      LEFT OUTER JOIN docreg
                   ON path.pathid = docreg.pathid
             GROUP BY path.pathid )
                   AS docnum
                WHERE entries = 0
        });
    $sth->execute();
    if ($sth->rows == 0) {return undef; }
    my (@dlist, %hdlist);
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@dlist, $ref->{pathid});
        $hdlist{$ref->{pathid}} = 1;
    }
    # path count
    $sth = $dbh->prepare('SELECT parent, COUNT(pathid) FROM path WHERE parent IN (' . ('?,' x $#dlist) . '?) GROUP BY parent');
    $sth->execute(@dlist);
    if ($sth->rows == 0) {return undef; }
    my @plist;
    while (my $ref = $sth->fetchrow_hashref()) {
        delete($hdlist{$ref->{parent}});
    }
    my @ref = keys(%hdlist);
    return \@ref;
#    while (my $ref = $sth->fetchrow_hashref()) {push(@plist, $ref->{parent}); }
#    return \@plist;
}

sub GetPathInfo {
    my ($self, $pathid) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT * FROM path WHERE pathid = ?');
    $sth->execute($pathid);
    if ($sth->rows != 1) {return undef; }
    my $ref = $sth->fetchrow_hashref();
    $ref = PSMT::Util->AddShortDesc($ref);
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
    $fname .= $docinfo->{filename} . '.' . $finfo->{fileext};
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
    return PSMT::Util->GetMimeType($ext);
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
    return $self->_attach_file_info($sth->fetchrow_hashref());
}

sub GetFilesInfo {
    my ($self, $fileids) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth;
    my $uname = PSMT->user->get_uid();
    my $sthstr = 'SELECT * FROM docinfo WHERE fileid IN (' . ('?, ' x $#$fileids) . '?) ';
    if (PSMT->user->is_inadmin()) {
        $sth = $dbh->prepare($sthstr);
        $sth->execute(@$fileids);
    } else {
        $sth = $dbh->prepare($sthstr . 'AND (enabled = 1 OR uname = ?');
        $sth->execute(@$fileids, $uname);
    }
    if ($sth->rows() == 0) {return undef; }
    my ($ref, %ret);
    while ($ref = $sth->fetchrow_hashref()) {
        $ret{$ref->{fileid}} = $ref;
        $ret{$ref->{fileid}}->{size} = $self->GetFileSize($ref->{fileid});
    }
    return \%ret;
}

sub RegNewDoc {
    my ($self, $pathid, $name, $desc, $secure) = @_;
    my $docid = 0;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE', 'docreg WRITE');
    $self->ValidateNameInPath($pathid, $name);
    my $sth = $dbh->prepare('INSERT INTO docreg (pathid, filename, description, secure) VALUES (?, ?, ?, ?)');
    if ($sth->execute($pathid, $name, $desc, $secure) == 0) {return $docid; }
    $docid = $dbh->db_last_key('docreg', 'docid');
    $dbh->db_unlock_tables();
# No Need To Send Mail in 'RegNewDoc' : Always Followed by 'RegNewFile' !
#    PSMT->email()->NewDocInPath($pathid, $docid);
    return $docid;
}

sub RegNewFile {
    my ($self, $ext, $docid, $desc, $is_add, $hash, $daddrs) = @_;
    return $self->RegNewFileTime($ext, $docid, $desc, $is_add, -1, $hash, $daddrs);
}

sub RegNewFileTime {
    my ($self, $ext, $docid, $desc, $is_add, $uptime, $hash, $daddrs) = @_;
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
    if ($uptime < 0) {
        $sth = $dbh->prepare('INSERT INTO docinfo (fileid, fileext, docid, uptime, uname, srcip, description, shahash) VALUES (?, ?, ?, NOW(), ?, ?, ?, ?)');
        $sth->execute($fileid, $ext, $docid, $uname, $srcip, $desc, $hash);
    } else {
        $sth = $dbh->prepare('INSERT INTO docinfo (fileid, fileext, docid, uptime, uname, srcip, description, shahash) VALUES (?, ?, ?, from_unixtime(?), ?, ?, ?, ?)');
        $sth->execute($fileid, $ext, $docid, $uptime, $uname, $srcip, $desc, $hash);
    }
    $dbh->db_unlock_tables();
    if ($is_add == TRUE) {PSMT->email()->NewFileInDoc($docid, $fileid, $daddrs); }
    else {PSMT->email()->NewDocInPath($docid, $fileid, $daddrs); }
    return $fileid;
}

sub RegNewPath {
    my ($self, $cur, $path, $desc, $group, $daddrs) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE', 'docreg WRITE');
    $self->ValidateNameInPath($cur, $path);
    my $sth = $dbh->prepare('INSERT INTO path (parent, pathname, description) VALUES (?, ?, ?)');
    if ($sth->execute($cur, $path, $desc) == 0) {return 0; }
    my $pathid = $dbh->db_last_key('path', 'pathid');
    $dbh->db_unlock_tables();
    PSMT::Access->SetPathAccessGroup($pathid, $group);
    PSMT->email()->NewPathInPath($cur, $pathid, $daddrs);
    return $pathid;
}

sub UpdatePathInfo {
    my ($self, $pid, $old, $new) = @_;
    my $dbh = PSMT->dbh;
    my $sth;
    my $cur_access = undef;
    if (! PSMT->user->is_inadmin()) {PSMT::Error->throw_error_user('update_permission'); }
    $dbh->db_lock_tables('path WRITE', 'access_path WRITE');
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
    # check circular reference
    if ($self->CheckPathIdInParent($pid, $new->{parent})) {
        PSMT::Error->throw_error_user('invalid_path_circular'); 
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

sub UpdateDocInfo {
    my ($self, $did, $old, $new) = @_;
    my $dbh = PSMT->dbh;
    my $sth;
    my $cur_access = undef;
    # check security
    if (! PSMT->user->is_inadmin()) {PSMT::Error->throw_error_user('update_permission'); }
    if ((! PSMT->user->is_inadmin()) && ($old->{secure} ne $new->{secure}))
        {PSMT::Error->throw_error_user('update_permission'); }
    # lock
    $dbh->db_lock_tables('docreg WRITE', 'path WRITE', 'access_doc WRITE');
    my $docinfo = $self->GetDocInfo($did);
    if (! defined($docinfo)) {PSMT::Error->throw_error_user('invalid_doc_id'); }
    # check current match
    if (($docinfo->{filename} ne $old->{name}) || 
        ($docinfo->{description} ne $old->{description}) ||
        ($docinfo->{pathid} ne $old->{pathid}) ||
        ($docinfo->{secure} ne $old->{secure}) ) {
        PSMT::Error->throw_error_user('old_not_match');
    }
    # check collision if changing parent or name
    if ($docinfo->{pathid} ne $new->{pathid}) {
        $cur_access = PSMT::Access->ListFullDocRestrict($did);
    }
    if (($docinfo->{pathid} ne $new->{pathid}) ||
        ($docinfo->{filename} ne $new->{name})) {
        $self->ValidateNameInPath($new->{pathid}, $new->{name});
    }
    # update
    $sth = $dbh->prepare(
        'UPDATE docreg SET pathid = ?, filename = ?, description = ?, secure = ? WHERE docid = ?');
    if ($sth->execute($new->{pathid}, $new->{name}, $new->{description}, $new->{secure}, $did) == 0) {
        PSMT::Error->throw_error_code('update_info_failed');
    }
    # set group restriction if parent path changed
    if (defined($cur_access)) {
        PSMT::Access->SetDocAccessGroup($did, $cur_access);
    }
    $dbh->db_unlock_tables();
}

sub UpdateFileDesc {
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

sub UpdateFileVersion {
    my ($self, $fid, $ver) = @_;
    my $finfo = $self->GetFileInfo($fid);
    if (! defined($finfo)) {PSMT::Error->throw_error_user('invalid_fileid'); }
    if ((! PSMT->user->is_inadmin()) && ($finfo->{uname} ne PSMT->user->get_uid())) {
        PSMT::Error->throw_error_user('update_permission');
    }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo WRITE');
    my $sth = $dbh->prepare('UPDATE docinfo SET version = ? WHERE fileid = ?');
    if ($sth->execute($ver, $fid) == 0) {
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
    # file reg finished, unlock WRITE temporary, if we need do READ again
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('fullindex WRITE');
    my $fidx_obj = new PSMT::FullSearchMroonga(TRUE);
    $fidx_obj->AddNewFile($fid);
    return TRUE;
}

sub SaveToDav {
    my ($self, $fh, $hash) = @_;
    my $objSHA = new Digest::SHA->new(HASH_SIZE);
    my ($out, $fname) = tempfile( DIR => PSMT::Config->GetParam('dav_path') );
    my $buf;
    binmode $out;
    if (defined($hash)) {
        while (read($fh, $buf, 1024)) {
            print $out $buf;
            $objSHA->add($buf);
        }
    } else {
        while (read($fh, $buf, 1024)) {
            print $out $buf;
        }
    }
    close $out;
    if (defined($hash)) {$$hash = $objSHA->b64digest; }
    my $cmatch;
    if (defined($cmatch = PSMT::File->CheckFileHash($$hash))) {
        unlink $fname;
        PSMT::Template->set_vars('matched', $cmatch);
        PSMT::Error->throw_error_user('file_hash_match');
    }
    return $fname;
}

sub CheckDavHash {
    my ($self, $fname) = @_;
    my $objSHA = new Digest::SHA->new(HASH_SIZE);
    open(INDAT, $fname);
    binmode INDAT;
    my $buf;
    while (read(INDAT, $buf, 1024)) {$objSHA->add($buf); }
    my $chash = $objSHA->b64digest;
    my $cmatch;
    if (defined($cmatch = PSMT::File->CheckFileHash($chash))) {
        PSMT::Template->set_vars('matched', $cmatch);
        PSMT::Error->throw_error_user('file_hash_match');
    }
    return $chash;
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
    $dbh->db_lock_tables('path READ', 'docreg READ');
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

# fid = reference to hash of files
#   key: full path to stored file = GetFilePath($fid)/$fid
#   value: target file path/name in zip
# head = HTTP header to be printed
# fname = download filename for password reminder (without .zip)
sub MakeEncZipFile {
    my ($self, $fid, $head, $fname) = @_;
    my $tdir = PSMT::Constants::LOCATIONS()->{'rel_zipcache'};
    if (! -d PSMT::Constants::LOCATIONS()->{'rel_zipcache'}) {mkdir($tdir); }
    my $dir = tempdir(TEMPLATE => 'XXXXXXXX', DIR => $tdir);
    my ($cfid, %dirs_made, $dir_tomake, @dirs_tmp);
    foreach $cfid (keys %$fid) {
        if (rindex($fid->{$cfid}, '/') > -1) {
            $dir_tomake = substr($fid->{$cfid}, 0, rindex($fid->{$cfid}, '/'));
            if (! defined($dirs_made{$dir_tomake})) {
                @dirs_tmp = File::Path::mkpath($dir . '/' . $dir_tomake);
                foreach (@dirs_tmp) {$dirs_made{$_} = 1; }
            }
        }
        symlink($cfid, $dir . '/' . $fid->{$cfid}); # XXX do nothing for failed files....
    }
    my $pass = PSMT::Util->GetHashString($fname);
    my $fh;
    chdir $dir;
    open($fh, "$bin_zip -0 -P \"$pass\" -q -r -UN=Ignore - '.' |");
    chdir '../../..';
    if (! defined($fh)) {PSMT::Error->throw_error_code('crypt_zip'); }
    print $head;
    print <$fh>;
    close($fh);
    PSMT::Email->SendPassword("$fname.zip", PSMT->user->get_uid(), $pass);
    File::Path::rmtree([ $dir ]);
    return $fh;
}

sub CheckPathIdInParent {
    my ($self, $check, $start) = @_;
    my $cid = $start;
    if ($check == $cid) {return TRUE; }
    while (($cid = $self->GetPathIdForParent($cid)) > -1) {
        if ($cid == $check) {return TRUE; }
    }
    return FALSE;
}

sub CheckMimeIsView {
    my ($self, $mime) = @_;
    my $vm = PSMT::Config->GetParam('view_mime');
    my @view = split(/,/, $vm);
    my $cview;
    foreach $cview (@view) {
        $cview =~ s/^ *(.*?) *$/$1/;
        if (index($mime, $cview) > -1) {return TRUE; }
    }
    return FALSE;
}

# check pathname exists or not with name and parentId
sub CheckPathExist {
    my ($self, $pid, $name) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sth = $dbh->prepare('SELECT pathid FROM path WHERE parent = ? AND pathname = ?');
    $sth->execute($pid, $name);
    if ($sth->rows() == 0) {return -1; }
    return $sth->fetchrow_hashref()->{pathid};
}

sub CheckDocExist {
    my ($self, $pid, $name) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ');
    my $sth = $dbh->prepare('SELECT docid FROM docreg WHERE pathid = ? AND filename = ?');
    $sth->execute($pid, $name);
    if ($sth->rows() == 0) {return -1; }
    return $sth->fetchrow_hashref()->{docid};
}

sub DeleteEmptyPath {
    my ($self, $pid) = @_;
    my $tnum;
    $tnum = $self->ListDocsInPath($pid);
    if ($#$tnum > -1) {return FALSE; }
    $tnum = $self->ListPathIdInPath($_);
    if ($#$tnum > -1) {return FALSE; }
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path WRITE');
    my $sth = $dbh->prepare('DELETE FROM path WHERE pathid = ?');
    if ($sth->execute($pid) == 0) {
        return FALSE;
    }
    return TRUE;
}

sub SearchPath {
    my ($self, $name, $desc, $cond) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('path READ');
    my $sthstr = 'SELECT * FROM path WHERE ';
    my @stharg;
    if (defined($name)) {
        $sthstr .= 'pathname REGEXP ? ';
        if (defined($desc)) {$sthstr .= ($cond) ? 'AND ' : 'OR '; }
        push(@stharg, $name);
    }
    if (defined($desc)) {
        $sthstr .= 'description REGEXP ?';
        push(@stharg, $desc);
    }
    my $sth = $dbh->prepare($sthstr);
    $sth->execute(@stharg);
    if ($sth->rows() == 0) {return undef; }
    my ($ref, %ret);
    while ($ref = $sth->fetchrow_hashref()) {
        $ret{$ref->{pathid}} = $ref;
    }
    return \%ret;
}

sub SearchDocFile {
    my ($self, $name, $desc, $cond) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docreg READ', 'docinfo READ');
    my $sthstr = 
        qq {  SELECT docinfo.docid AS docid, docinfo.fileid AS fileid
                FROM docinfo
          INNER JOIN docreg
                  ON docinfo.docid = docreg.docid
               WHERE docinfo.enabled = 1
                 AND };
    my @stharg;
    if (defined($name)) {
        $sthstr .= 'docreg.filename REGEXP ? ';
        if (defined($desc)) {$sthstr .= ($cond) ? 'AND ' : 'OR '; }
        push(@stharg, $name);
    }
    if (defined($desc)) {
        $sthstr .= '(docinfo.description REGEXP ? OR docreg.description REGEXP ?)';
        push(@stharg, $desc);
        push(@stharg, $desc);
    }
    my $sth = $dbh->prepare($sthstr);
    $sth->execute(@stharg);
    if ($sth->rows() == 0) {return undef; }
    my ($ref, %ret);
    while ($ref = $sth->fetchrow_hashref()) {
        $ret{$ref->{fileid}} = $ref->{docid};
    }
    return \%ret;
}

sub ListFileNoHash {
    my ($self) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare("SELECT fileid FROM docinfo WHERE CHAR_LENGTH(shahash) <> ? OR shahash IS NULL");
    $sth->execute(HASH_LEN);
    my (@ret, $ref);
    while ($ref = $sth->fetchrow_hashref()) {push(@ret, $ref->{fileid}); }
    return \@ret;
}

sub AddFileHash {
    my ($self, $fid, $hash) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo WRITE');
    my $sth = $dbh->prepare("UPDATE docinfo SET shahash = ? WHERE fileid = ?");
    if ($sth->execute($hash, $fid) == 0) {
        return FALSE;
    }
    return TRUE;
}

sub CheckFileHash {
    my ($self, $hash) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ');
    my $sth = $dbh->prepare('SELECT fileid FROM docinfo WHERE shahash = ?');
    $sth->execute($hash);
    if ($sth->rows() == 0) {return undef; }
    my ($ref, @ret);
    while ($ref = $sth->fetchrow_hashref()) {push(@ret, $ref->{fileid}); }
    return \@ret;
}

sub ListFileHashDup {
    my ($self) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('docinfo READ', 'docreg READ');
# same issue, not locked for subquery
#    my $sth = $dbh->prepare(
#        qq{       SELECT docinfo.*, pathid, filename, secure
#                    FROM docinfo
#              INNER JOIN (
#                  SELECT shahash AS duphash
#                    FROM docinfo
#                GROUP BY shahash
#                  HAVING COUNT(fileid) > 1
#                       ) duphash
#                      ON duphash.duphash = docinfo.shahash
#               LEFT JOIN docreg
#                      ON docinfo.docid = docreg.docid
#        });

    # 1st, list dup hash
    my $sth = $dbh->prepare('SELECT shahash FROM docinfo GROUP BY shahash HAVING COUNT(fileid) > 1');
    $sth->execute();
    if ($sth->rows() == 0) {return undef; }
    my $ref;
    my @hash;
    while ($ref = $sth->fetchrow_hashref()) {push(@hash, $ref->{shahash}); }

    # 2nd build file list
    my $sth = $dbh->prepare('SELECT docinfo.*, pathid, filename, secure FROM docinfo LEFT JOIN docreg ON docinfo.docid = docreg.docid WHERE docinfo.shahash IN (' . ('?,' x $#hash) . '?)');
    $sth->execute(@hash);
    if ($sth->rows() == 0) {return undef; }
    my ($ref, %ret);
    while ($ref = $sth->fetchrow_hashref()) {
        if (defined($ret{$ref->{shahash}})) {
            push(@{$ret{$ref->{shahash}}}, $ref);
        } else {
            my $arr = ();
            push(@$arr, $ref);
            $ret{$ref->{shahash}} = $arr;
        }
    }
    return \%ret;
}

sub GetNextVersionForDoc {
    my ($self, $did) = @_;
    my $finfo = $self->GetDocLastPostFileInfo($did);
    if (! defined($finfo)) {return 1.0; }
    if (! defined($finfo->{'version'})) {return 1.0; }
    return floor($finfo->{'version'} + 1.0);
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

sub _attach_file_info {
    my ($self, $ref) = @_;
    if ((! defined($ref)) || (! defined($ref->{fileid})) || (! defined($ref->{fileext}))) {
        return undef;
    }
    $ref->{size} = $self->GetFileSize($ref->{fileid});
    $ref->{filemime} = PSMT::Util->GetMimeType($ref->{fileext});
    $ref->{preview} = PSMT::Util->IsPreview($ref->{filemime});
    return $ref;
}

1;

__END__


