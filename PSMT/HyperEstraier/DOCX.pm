# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - File Dumper - docx
#
# Copyright (C) 2011 - IPMU/PFS
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <atsushi.shimono@ipmu.jp>

package PSMT::HyperEstraier::DOCX;

use strict;

use base qw(Exporter);

use PSMT::Constants;

use Archive::Zip;
use Archive::Zip::MemberRead;
use XML::DOM;

%PSMT::HyperEstraier::DOCX::EXPORT = qw(
    new
    DumpText
);

my $docx_file = 'word/document.xml';

sub new {
    return @_;
}

sub DumpText {
    my ($self, $fname) = @_;
    if (! -R $fname) {return ""; }
    my $dump_text = '';

    my $obj_zip = Archive::Zip->new($fname);
    my $obj_fh = Archive::Zip::MemberRead->new($obj_zip, $docx_file);
    my $line;
    my $doc_cont = '';
    while (defined($line = $obj_fh->getline())) {$doc_cont .= $line; }

    my $obj_dom = new XML::DOM::Parser;
    my $obj_doc = $obj_dom->parse($doc_cont);
    my $nodes = $obj_doc->getElementsByTagName('w:t');
    my $node_cnt = $nodes->getLength;
    for (my $node_id = 0; $node_id < $node_cnt; $node_id ++) {
        $dump_text .= $nodes->item($node_id)->getFirstChild()->getData();
        $dump_text .= ' ';
    }
    return $dump_text;
}

1;

