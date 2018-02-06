#! /usr/bin/perl

use strict;

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
use PSMT::Archive;

my $obj = new PSMT;
my $obj_cgi = $obj->cgi();

if ((! defined($obj->config())) || (! defined($obj->user()))) {
    PSMT::Error->throw_error_user('system_invoke_error');
}

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

# check attribute configuration
my ($att_config, $att_fh);
$att_fh = $obj_cgi->upload('target_config');
if (defined($att_fh)) {
    my $cfmt= $obj_cgi->param('config_format');
    my ($cfh, $cdat);
    foreach (<$att_fh>) {
        chomp();
        utf8::decode($_);
        $cdat .= $_ . "\n";
    }
    if (! defined($cfmt))
        {PSMT::Error->throw_error_user('invalid_config_source'); }
    if ($cfmt eq 'tsv') {
        $att_config = PSMT::Archive->ReadFilesConfigTSV($cdat);
    } elsif ($cfmt eq 'json') {
        $att_config = PSMT::Archive->ReadFilesConfigJson($cdat);
    } else {PSMT::Error->throw_error_user('invalid_config_source'); }
    if (! defined($att_config))
        {PSMT::Error->throw_error_user('invalid_config_source'); }
    if (defined($obj_cgi->param('config_confirm'))) {
        PSMT::Archive->StoreFilesConfig($att_config, $src . '.json');
        $obj->template->set_vars('pid', $pid);
        if (rindex($src,'/') > -1) {
            $src = substr($src, rindex($src, '/') + 1);
        }
        $obj->template->set_vars('dav', $src);
        $obj->template->set_vars('config', $att_config);
        $obj->template->process('zipadd-confirm', 'html');
        exit;
    }
} elsif ((defined($obj_cgi->param('config_format'))) && 
         ($obj_cgi->param('config_format') eq 'dav') &&
         (-f $src . '.json')) {
    open(JSON, $src . '.json');
    my $cdat;
    foreach (<JSON>) {$cdat .= $_ . "\n"; }
    close(JSON);
    $att_config = PSMT::Archive->ReadFilesConfigJson($cdat);
}

my ($flist, $dlist, $iflist, $idlist) = PSMT::Archive->Extract($src);
unlink($src);
unlink($src . '.json');
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

# reorg from @$att_config to hashes
# %att_doc{path+docname} = { docdesc => '', secure => '' }
# %att_file{fullname} = id in @att_config
#   $att_config[$att_file{'AAA'}]->{filename} = 'AAA'
my (%att_doc, %att_file, $cacdoc, $cidx);
foreach (0 ... $#$att_config) {
    $att_file{$att_config->[$_]->{filename}} = $_;
    if (($cidx = rindex($att_config->[$_]->{filename}, '.')) > -1) {
        $cacdoc = substr($att_config->[$_]->{filename}, 0, $cidx);
        if (defined($att_doc{$cacdoc})) {
            if ((! defined($att_doc{$cacdoc}->{docdesc})) && 
                (defined($att_config->[$_]->{docdesc}))) {
                $att_doc{$cacdoc}->{docdesc} = $att_config->[$_]->{docdesc};
            }
            if ((! defined($att_doc{$cacdoc}->{secure})) && 
                (defined($att_config->[$_]->{secure}))) {
                $att_doc{$cacdoc}->{secure} = $att_config->[$_]->{secure};
            }
        } else {
            # even if att_config key not defined, it just returns undef
            $att_doc{$cacdoc} = { 'docdesc' => $att_config->[$_]->{docdesc}, 
                'secure' => $att_config->[$_]->{secure} };
        }
    }
}

# entry files
# keep did->version
my %dver;
my ($cdid, $cname, $cext, $cfid, $cdcnf);
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
        if (defined($cdcnf = $att_doc{$_->{dirname} . '/' . $cname})) {
            if (! defined($cdcnf->{docdesc})) {$cdcnf->{docdesc} = ''; }
            if (! defined($cdcnf->{secure})) {$cdcnf->{secure} = FALSE; }
        } else {
            $cdcnf = { 'docdesc' => '', 'secure' => FALSE };
        }
        $cdid = PSMT::File->RegNewDoc($didlist{$_->{dirname}}, $cname, 
            $cdcnf->{docdesc}, $cdcnf->{secure});
        if ($cdid == 0) {
            &AddUpfailed($_, 'doc', 'invalid_doc');
            next;
        } # what to do?
#        if ($cdid == 0) {PSMT::Error->throw_error_user('doc_add_failed'); }
    }
    if (defined($cdcnf = $att_file{$_->{fullname}})) {
        $cdcnf = $att_config->[$cdcnf];
        if (! defined($cdcnf->{uptime}))
            {$cdcnf->{uptime} = $_->{lastmodified}; }
        if (! defined($cdcnf->{version})) {
            if (defined($dver{$cdid})) {$dver{$cdid} = $dver{$cdid} + 0.1; }
            else {$dver{$cdid} = PSMT::File->GetNextVersionForDoc($cdid); }
            $cdcnf->{version} = $dver{$cdid};
        }
        if (! defined($cdcnf->{filedesc})) {$cdcnf->{filedesc} = ''; }
        if (! defined($cdcnf->{uname}))
            {$cdcnf->{uname} = PSMT->user()->get_uid(); }
    } else {
        if (defined($dver{$cdid})) {$dver{$cdid} = $dver{$cdid} + 0.1; }
        else {$dver{$cdid} = PSMT::File->GetNextVersionForDoc($cdid); }
        $cdcnf = {
            'filedesc' => '',
            'version' => $dver{$cdid},
            'uptime' => $_->{lastmodified},
            'uname' => PSMT->user()->get_uid(),
        };
    }
    # need to deal with uname
    $cfid = PSMT::File->RegNewFileTime($cext, $cdid, $cdcnf->{filedesc}, FALSE, 
        $cdcnf->{uptime}, $_->{stored}, $_->{shahash}, undef, $cdcnf->{version},
        $cdcnf->{uname});
    if (! defined($cfid)) {
        &AddUpfailed($_, 'doc', 'fail_add_file');
#        &AddUpfailed($_, 'doc', 'fail_store_file');
        next;
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

sub EraseFiles {
    my $clist;
    foreach $clist (@_) {foreach (@$clist) {unlink $_->{stored}; } }
}

