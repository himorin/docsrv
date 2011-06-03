# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - HyperEstraier wrapper
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::HyperEstraier;

use strict;

use base qw(Exporter);

use PSMT::Constants;
use PSMT::Config;
use PSMT::Util;
use PSMT::User;
use PSMT::Error;
use PSMT::Template;
use PSMT::File;

use Estraier;

%PSMT::HyperEstraier::EXPORT = qw(
    new
    AddNewFile
    ExecSearch
);

my $obj_db;

sub END {
    _close();
}

sub new {
    my ($self, $mode) = @_;
    $self->_open($mode);
    return $self;
}

sub ExecSearch {
    my ($self, $phrase) = @_;
    my $cond = new Condition();
    $cond->set_phrase($phrase);
    my $result = $obj_db->search($cond);
    my @fids;
    my $obj_doc;
    foreach my $id ( 0 .. ($result->doc_num() - 1)) {
        $obj_doc = $obj_db->get_doc($result->get_doc_id($id), 0);
        next unless(defined($obj_doc));
        push(@fids, $obj_doc->attr('@uri'));
    }
    return \@fids;
}

sub AddNewFile {
    my ($self, $fid) = @_;
    my $finfo = PSMT::File->GetFileInfo($fid);
    if ($finfo->{fileext} eq 'pdf') {$self->_add_pdf($fid); }
}

#------------------------------------------------------------------------

sub _add_pdf {
    my ($self, $fid) = @_;
    my $cmd = HE_FILE_FILTER;
    my $fh;
    my $fname = PSMT::File->GetFilePath($fid) . $fid;
    open($fh, "$cmd->{pdf} $fname - |");
    $self->_add($fid, $fh);
    close($fh);
}

sub _add {
    my ($self, $fid, $fh) = @_;
    my $obj_doc = new Document();
    my $finfo = PSMT::File->GetFileInfo($fid);
    my $dinfo = PSMT::File->GetDocInfo($finfo->{docid});
    $obj_doc->add_attr('@uri', $fid);
    $obj_doc->add_attr('@title', $dinfo->{filename} . '/' . $finfo->{description});
    $obj_doc->add_attr('@author', $finfo->{uname});
    $obj_doc->add_attr('@type', PSMT::File->GetFileExt($fid));
    foreach (<$fh>) {
        chomp();
        $obj_doc->add_text($_);
    }
    $obj_db->put_doc($obj_doc, Database::PDCLEAN);
}

sub _open {
    my ($self, $is_write) = @_;
    my $db = PSMT->config->GetParam('he_dir');
    $obj_db = new Database();
    my $flag = Database::DBREADER;
    if (defined($is_write) && ($is_write == TRUE)) {
        $flag = Database::DBWRITER | Database::DBCREAT;
    }
    unless($obj_db->open($db, $flag)) {
        $obj_db = undef;
        PSMT::Error->throw_error_code('he_open_failed');
    }
    return TRUE;
}

sub _close {
    my ($self) = @_;
    if (defined($obj_db)) {$obj_db->close(); }
}


1;

__END__


