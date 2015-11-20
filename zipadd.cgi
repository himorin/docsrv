#! /usr/bin/perl

use strict;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Temp qw/ tempfile tempdir /;                                          
use Encode;

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
my ($flist, $dlist) = &ExtractZip($src);
#unlink($src);

# entry directories
my (%didlist, $cdir, $cpid, $tid, $cpdir, $cldir);
foreach $cdir (@$dlist) {
    if (index($cdir, '/') != -1) {
        $cpdir = substr($cdir, 0, rindex($cdir, '/'));
        $cldir = substr($cdir, rindex($cdir, '/') + 1);
        if (! defined($didlist{$cpdir})) {push(@$dlist, $cdir); next; }
        $cpid = $didlist{$cpdir};
    } else {
        $cpid = $pid;
        $cldir = $cdir;
    }
    if (($tid = PSMT::File->CheckPathExist($cpid, $cldir)) != -1) {
        $didlist{$cdir} = $tid;
    } else {
        $didlist{$cdir} = PSMT::File->RegNewPath($cpid, $cldir, '', undef, undef);
    }

}

# entry files
my ($cdid, $cname, $cext, $cfid);
my (@upfailed, @uploaded);
foreach (@$flist) {
    $cext = 'dat';
    $cname = $_->{filename};
    if (rindex($cname, '.') != -1) {
        $cext = substr($cname, rindex($cname, '.') + 1);
        $cname = substr($cname, 0, rindex($cname, '.'));
    }
    # check doc exist
    $cdid = PSMT::File->GetIdFromName($didlist{$_->{dirname}}, $cname);
    if ($cdid == 0) {
        $cdid = PSMT::File->RegNewDoc($didlist{$_->{dirname}}, $cname, "", FALSE);
        if ($cdid == 0) {
            push(@upfailed, $_);
            next;
        } # what to do?
#        if ($cdid == 0) {PSMT::Error->throw_error_user('doc_add_failed'); }
    }
    $cfid = PSMT::File->RegNewFileTime($cext, $cdid, '', FALSE, $_->{lastmodified}, undef);
    if (! defined($cfid)) {
        push(@upfailed, $_);
        next;
    } # what to do?
#    if (! defined($cfid)) {
#        PSMT::Error->throw_error_user('file_register_failed');
#    }
    if (PSMT::File->MoveNewFile($_->{stored}, $cfid) != TRUE) {
        push(@upfailed, $_);
        next;
#        PSMT::Error->throw_error_user('file_register_failed');
    }
    $_->{did} = $cdid;
    $_->{fid} = $cfid;
    $_->{storename} = $_->{dirname} . '/' . $cname;
    $_->{ext} = $cext;
    push(@uploaded, $_);
}


$obj->template->set_vars('mode', 'result');
$obj->template->set_vars('pid', $pid);
$obj->template->set_vars('full_path', PSMT::File->GetFullPathFromId($pid));
$obj->template->set_vars('up_fail', \@upfailed);
$obj->template->set_vars('up_succ', \@uploaded);

$obj->template->process('zipadd', 'html');


exit;

sub ExtractZip {
    my ($fname) = @_;
    my $obj_zip = Archive::Zip->new();
    if ($obj_zip->read($fname) != AZ_OK) {
        return undef;
    }
    my @fmem = $obj_zip->members();
    my (@rfile, @rdir, $dtdos, $extfile, $out);
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
            ($out, $extfile) = tempfile( DIR => PSMT::Config->GetParam('dav_path'));
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
            if (substr($extfile, length($extfile) - 1) eq '/') {
                $extfile = substr($extfile, 0, length($extfile) - 1);
            }
            push(@rdir, $extfile);
        }
    }
    return (\@rfile, \@rdir);
}

