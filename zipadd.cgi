#! /usr/bin/perl

use strict;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Temp qw/ tempfile tempdir /;                                          
use Encode;
use Digest::SHA;

use PSMT;

use PSMT::Constants;
use PSMT::Template;
use PSMT::Config;
use PSMT::CGI;
use PSMT::DB;
use PSMT::User;
use PSMT::Util;
use PSMT::File;
use PSMT::Access;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

my $zip_enc = PSMT::Config->GetParam('zip_win_encoding');

# if not POST && pid invalid, redirect to path view
my $pid = $obj_cgi->param('pid');
my $pathinfo;
if (defined($pid) && ($pid != 0)) {
    # first check pid is valid; if valid clear path
    $pathinfo = PSMT::File->GetPathInfo($pid);
    if (! defined($pathinfo)) {
        PSMT::Error->throw_error_user('invalid_path_id');
    }
} elsif (defined($pid) && ($pid == 0)) {
} else {
    PSMT::Error->throw_error_user('invalid_path_id');
}
if ($pid != -1) {
    PSMT::Access->CheckForPath($pid);
}
if ($obj_cgi->request_method() ne 'POST') {
    $obj->template->set_vars('mode', 'upload');
    $obj->template->set_vars('pid', $pid);
    $obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
    $obj->template->set_vars('dav_file', PSMT::File->ListDavFile());
    $obj->template->process('zipadd', 'html');
    exit;
}

# check file uploaded
#  source: dav or upload
#  dav_source: filename at webdav
#  target_file: file upload
my $source = $obj_cgi->param('source');
my $src = undef;
if ($source eq 'dav') {
    $src = $obj_cgi->param('dav_source');
    $src = PSMT::Config->GetParam('dav_path') . '/' . $src;
    if (! -f $src) {PSMT::Error->throw_error_user('null_file_upload'); }
} elsif ($source eq 'upload') {
    my $fh = $obj_cgi->upload('target_file');
    if (! defined($fh)) {PSMT::Error->throw_error_user('null_file_upload'); }
    $src = PSMT::File->SaveToDav($fh);
} else {
    PSMT::Error->throw_error_user('invalid_file_source');
}
my ($flist, $dlist, $iflist, $idlist) = &ExtractZip($src);
unlink($src);
if ((! defined($flist)) || ($#$flist < 0)) {
    &EraseFiles($flist, $iflist);
    PSMT::Error->throw_error_user('null_file_upload');
}

# check hash
my %hashmatch;
my $objSHA = new Digest::SHA->new(HASH_SIZE);
foreach (@$flist) {
    if ((substr($_->{fullname}, 0, 8) ne '__MACOSX') &&
        ($_->{filename} ne '.DS_Store') &&
        (substr($_->{filename}, 0, 2) ne '._')) {
        $objSHA->reset(HASH_SIZE);
        open(INDAT, $_->{stored});
        binmode INDAT;
        my $buf;
        while (read(INDAT, $buf, 1024)) {$objSHA->add($buf); }
        my $chash = $objSHA->b64digest;
        $_->{shahash} = $chash;
        my $cmatch;
        if (defined($cmatch = PSMT::File->CheckFileHash($chash))) {
            $hashmatch{$_->{fullname}} = $cmatch;
        }
    }
}
if (keys %hashmatch > 0) {
    &EraseFiles($flist, $iflist);
    $obj->template->set_vars('hashmatch', \%hashmatch);
    $obj->template->process('zipadd-fail', 'html');
    exit;
}

# uploaded only contains hash for document
# upfailed both path and document, also 'error' value
my (@upfailed, @uploaded);

# Ignore directory/file with:
#  file with '._XXXX'
#  directory as '__MACOSX' (exact)
# entry directories
my (%didlist, %didign, $cdir, $cpid, $tid, $cpdir, $cldir);
$didlist{''} = $pid;
foreach $cdir (@$idlist) {
    &AddUpfailed({'fullname' => $cdir}, 'path', 'invalid_encoding');
    $didign{$cdir} = TRUE;
}
while ($cdir = shift(@$dlist)) {
    if (index($cdir, '/') != -1) {
        $cpdir = substr($cdir, 0, rindex($cdir, '/'));
        $cldir = substr($cdir, rindex($cdir, '/') + 1);
        if (defined($didign{$cpdir})) {
            $didign{$cdir} = TRUE;
            &AddUpfailed({'fullname' => $cdir}, 'path', 'in_invalid_path');
            next;
        }
        if (! defined($didlist{$cpdir})) {push(@$dlist, $cdir); next; }
        $cpid = $didlist{$cpdir};
    } else {
        $cpid = $pid;
        $cldir = $cdir;
    }
    if ($cldir eq '__MACOSX') {
        $didign{$cdir} = TRUE;
        &AddUpfailed({'fullname' => $cdir}, 'path', 'invalid_path');
    } elsif (($tid = PSMT::File->CheckPathExist($cpid, $cldir)) != -1) {
        $didlist{$cdir} = $tid;
    } elsif (PSMT::File->CheckDocExist($cpid, $cldir) != -1) {
        $didign{$cdir} = TRUE;
        &AddUpfailed({'fullname' => $cdir}, 'path', 'path_db_doc');
    } else {
        $didlist{$cdir} = PSMT::File->RegNewPath($cpid, $cldir, '', undef, undef);
    }
}

# entry files
# keep did->version
my %dver;
my ($cdid, $cname, $cext, $cfid);
foreach (@$iflist) {&AddUpfailed($_, 'doc', 'invalid_encoding'); }
foreach (@$flist) {
    $cext = 'dat';
    $cname = $_->{filename};
    if (rindex($cname, '.') != -1) {
        $cext = substr($cname, rindex($cname, '.') + 1);
        $cname = substr($cname, 0, rindex($cname, '.'));
        if ($cname eq '') {$cname = $_->{filename}; }
    }
    # check directory valid
    if (defined($didign{$_->{dirname}}) ||
        (! defined($didlist{$_->{dirname}}))) {
        &AddUpfailed($_, 'doc', 'in_invalid_path');
        next;
    }
    # check filename valid
    if (substr($_->{filename}, 0, 2) eq '._') {
        &AddUpfailed($_, 'doc', 'invalid_doc');
        next;
    }
    # check doc exist
    $cdid = PSMT::File->GetIdFromName($didlist{$_->{dirname}}, $cname);
    if ($cdid == 0) {
        if (PSMT::File->CheckPathExist($didlist{$_->{dirname}}, $cname) > -1) {
            &AddUpfailed($_, 'doc', 'path_db_doc');
            next;
        }
        $cdid = PSMT::File->RegNewDoc($didlist{$_->{dirname}}, $cname, "", FALSE);
        if ($cdid == 0) {
            &AddUpfailed($_, 'doc', 'invalid_doc');
            next;
        } # what to do?
#        if ($cdid == 0) {PSMT::Error->throw_error_user('doc_add_failed'); }
    }
    if (defined($dver{$cdid})) {
        $dver{$cdid} = $dver{$cdid} + 0.1;
    } else {
        $dver{$cdid} = PSMT::File->GetNextVersionForDoc($cdid);
    }
    $cfid = PSMT::File->RegNewFileTime($cext, $cdid, '', FALSE, $_->{lastmodified}, $_->{shahash}, undef, $dver{$cdid});
    if (! defined($cfid)) {
        &AddUpfailed($_, 'doc', 'fail_add_file');
        next;
    } # what to do?
#    if (! defined($cfid)) {
#        PSMT::Error->throw_error_user('file_register_failed');
#    }
    if (PSMT::File->MoveNewFile($_->{stored}, $cfid) != TRUE) {
        &AddUpfailed($_, 'doc', 'fail_store_file');
        next;
#        PSMT::Error->throw_error_user('file_register_failed');
    }
    $_->{did} = $cdid;
    $_->{fid} = $cfid;
    $_->{storename} = $_->{dirname} . '/' . $cname;
    $_->{ext} = $cext;
    $_->{version} = $dver{$cdid};
    push(@uploaded, $_);
}


$obj->template->set_vars('mode', 'result');
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
$obj->template->set_vars('up_fail', \@upfailed);
$obj->template->set_vars('up_succ', \@uploaded);

$obj->template->process('zipadd', 'html');


exit;

sub AddUpfailed {
    my ($hash, $mode, $err) = @_;
    $hash->{mode} = $mode;
    $hash->{error} = $err;
    push(@upfailed, $hash);
    if (defined($hash->{stored})) {unlink $hash->{stored}; }
}

# XXX: check on path/file names non-UTF8
sub ExtractZip {
    my ($fname) = @_;
    my $obj_zip = Archive::Zip->new();
    if ($obj_zip->read($fname) != AZ_OK) {
        return undef;
    }
    my @fmem = $obj_zip->members();
    my (@rfile, @rdir, @invfile, @invdir, $dtdos, $extfile, $out);
    # create directory for temporary files in zipupload
    # no to expose files in uploaded zip into normal file from webdav operation
    my $tmp_dir = PSMT::Config->GetParam('dav_path') . '/' . PATH_SP_ZIPADD;
    mkdir $tmp_dir;
    foreach (@fmem) {
        my $hret = {};
        if (ref $_ eq 'Archive::Zip::ZipFileMember') {
            $hret->{fullname} = $_->{fileName};
            if ($obj_cgi->is_windows()) {
                $hret->{fullname} = Encode::decode($zip_enc, $hret->{fullname});
            }
            $hret->{lastmodified} = $_->lastModTime();
            $hret->{size} = $_->{uncompressedSize};
            if (index($hret->{fullname}, '/') > -1) {
                $hret->{filename} = substr($hret->{fullname},
                    rindex($hret->{fullname}, '/') + 1);
                $hret->{dirname} = substr($hret->{fullname}, 0,
                    rindex($hret->{fullname}, '/'));
            } else {
                $hret->{filename} = $hret->{fullname};
                $hret->{dirname} = '';
            }
            if (PSMT::Util->ValidateEncoding($hret->{fullname}) > 0) {
                push(@invfile, $hret);
                next;
            }
            ($out, $extfile) = tempfile( DIR => $tmp_dir );
            close $out;
            if ($obj_zip->extractMember($_->{fileName}, $extfile) == AZ_OK) {
                $hret->{stored} = $extfile;
            }
            push(@rfile, $hret);
        } elsif (ref $_ eq 'Archive::Zip::DirectoryMember') {
            $extfile = $_->{fileName};
            if ($obj_cgi->is_windows()) {
                $extfile = Encode::decode($zip_enc, $extfile);
            }
            if (PSMT::Util->ValidateEncoding($extfile) > 0) {
                push(@invdir, $extfile);
                next;
            }
            if (substr($extfile, length($extfile) - 1) eq '/') {
                $extfile = substr($extfile, 0, length($extfile) - 1);
            }
            push(@rdir, $extfile);
        }
    }
    # tweak for Windows zip
    my (%hrdir, $cdir);
    foreach (@rdir) {$hrdir{$_} = 1; }
    foreach (@rfile) {
        if ($_->{dirname} ne '') {
            if (! defined($hrdir{$_->{dirname}})) {$hrdir{$_->{dirname}} = 1; }
        }
    }
    @rdir = keys(%hrdir);
    return (\@rfile, \@rdir, \@invfile, \@invdir);
}

sub EraseFiles {
    my $clist;
    foreach $clist (@_) {foreach (@$clist) {unlink $_->{stored}; } }
}

