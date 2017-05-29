# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Archive handler (zip)
#
# Copyright (C) 2017 - : PFS
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <atsushi.shimono@ipmu.jp>

package PSMT::Archive;

use strict;

use base qw(Exporter);

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Encode;

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;
use PSMT::CGI;

%PSMT::Archive::EXPORT = qw(
    new

    Extract

    MakeEncrypted
    MakeNormal
);

my $bin_zip = '/usr/bin/zip';

sub new {
    my ($this) = @_;
    return $this;
}

# XXX: check on path/file names non-UTF8
sub Extract {
    my ($self, $fname) = @_;
    my $obj_zip = Archive::Zip->new();
    my $zip_enc = PSMT::Config->GetParam('zip_win_encoding');
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
            if (PSMT->cgi()->is_windows()) {
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
            if (PSMT->cgi()->is_windows()) {
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

# fid = reference to hash of files
#   key: full path to stored file = GetFilePath($fid)/$fid
#   value: target file path/name in zip
# head = HTTP header to be printed
# fname = download filename for password reminder (without .zip)
sub MakeEncrypted {
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
    return TRUE;
}

sub MakeNormal {
    my ($self, $path, $files, $head) = @_;
    # start zip object
    my $obj_zip = Archive::Zip->new();
    my $tname;
    my $zip_enc = PSMT::Config->GetParam('zip_win_encoding');
    if (! PSMT->cgi()->is_windows()) {$zip_enc = 'utf8'; }
    foreach $tname (@$path) {
        $tname = Encode::encode($zip_enc, $tname);
        $obj_zip->addDirectory($tname);
    }
    foreach (keys %$files) {
        $tname = $files->{$_};
        $tname = Encode::encode($zip_enc, $tname);
        $obj_zip->addFile($_, $tname);
    }
    print $head;
    $obj_zip->writeToFileHandle(*STDOUT);
    return TRUE;
}

################################################################## PRIVATE



1;

__END__




