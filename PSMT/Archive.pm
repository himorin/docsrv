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
use JSON;

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;
use PSMT::CGI;

%PSMT::Archive::EXPORT = qw(
    new

    Extract

    MakeEncrypted
    MakeNormal

    ParseConfig
    StoreConfig
    ReadFilesConfigJson
    ReadFilesConfigTSV
);

my $bin_zip = '/usr/bin/zip';

# Config parsers
#  ReadFilesConfig* : read from stream or file to internal hash
#    ReadFilesConfig* will call _validateFilesConfig right before returning hash
#  _validateFilesConfig : check and filter hash to defined structure
#    validation of values are not included
#    return undef if no valid item found
#
# REQ = required, OPT = option, SRD = only for stored files
# FilesConfig = [ {
#   filename (REQ): filename including ext and full path (in docsrv or zip archive)
#   uptime (OPT): uploaded timestamp
#   uname (OPT): uploaded username
#   filedesc (OPT): description for file
#   docdesc (OPT): description for document
#   secure (OPT): security flag for document
#   version (OPT): version number for file
#   shahash (STD): SHA hash
#   fileid (STD): docinfo.fileid
#   ext (SRD): extension recorded in database
# } ]
my $fcfields = [ 'filename', 'uptime', 'uname', 'filedesc', 'docdesc', 
   'secure', 'version', 'shahash', 'fileid', 'ext' ];

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

sub ReadFilesConfigJson {
    my ($self, $source) = @_;
    my $hash;
    $hash = decode_json($source);
    return $self->_validateFilesConfig($hash);
}

sub ReadFilesConfigTSV {
    my ($self, $source) = @_;
    my $hash = [];
    my @lines = split(/[\r\n]+/, $source);
    my @head = split(/\t/, shift(@lines));
    if ($#head < 1) {return undef; }
    # check filename is included
    my $isdef = FALSE;
    foreach (@head) {if ($_ eq 'filename') {$isdef = TRUE; }}
    if ($isdef != TRUE) {PSMT::Error->throw_error_code('config_filename_required'); }
    my @clarr;
    foreach (@lines) {
        @clarr = split(/\t/, $_, -1);
        if ($#head != $#clarr) {next; }
        my $chash = {};
        foreach (0 ... $#head) {
            $chash->{$head[$_]} = $clarr[$_];
        }
        push(@$hash, $chash);
    }
    return $self->_validateFilesConfig($hash);
}

sub StoreFilesConfig {
    my ($self, $config, $fname) = @_;
    my $fh;
    if (! defined($fname)) {
        ($fh, $fname) = tempfile(
            DIR => PSMT::Constants::LOCATIONS()->{'rel_zipcache'},
            SUFFIX => '.json'
        );
    } else {
        open($fh, "> $fname");
    }
    print $fh encode_json($config);
    close($fh);
    return $fname;
}

################################################################## PRIVATE

sub _validateFilesConfig {
    my ($self, $config) = @_;
    my $valed = [];
    my $corig;
    foreach (@$config) {
        my $vhash = {};
        $corig = $_;
        if ((! defined($corig->{filename})) ||
            ($corig->{filename} eq '')) {next; }
        foreach (@$fcfields) {
            if (defined($corig->{$_}) && ($corig->{$_} ne ''))
                {$vhash->{$_} = $corig->{$_}; }
        }
        # check values
        if (defined($vhash->{uptime}) && (! ($vhash->{uptime} > 0)))
            {delete $vhash->{uptime}; }
        if (defined($vhash->{secure}) && (! ($vhash->{secure} > 0)))
            {delete $vhash->{secure}; }
        if (defined($vhash->{version}) && (! ($vhash->{version} > 0)))
            {delete $vhash->{version}; }
        push(@$valed, $vhash);
    }
    if ($#$valed < 0) {return undef; }
    return $valed;
}



1;

__END__




