# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - File Dumper - xlsx
#
# Copyright (C) 2011 - IPMU/PFS
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <atsushi.shimono@ipmu.jp>

package PSMT::FullSearch::XLSX;

use strict;

use base qw(Exporter);

use PSMT::Constants;

use Archive::Zip;
use Archive::Zip::MemberRead;
use XML::DOM;

%PSMT::FullSearch::XLSX::EXPORT = qw(
    new
    DumpText
);

my $xlsx_file = 'xl/sharedStrings.xml';

sub new {
    return @_;
}

sub DumpText {
    my ($self, $fname) = @_;
    if (! -R $fname) {return ""; }
    my $dump_text = '';

    my $obj_zip = Archive::Zip->new($fname);
    if (! defined($obj_zip)) {return ""; }
    if (! defined($obj_zip->memberNamed($xlsx_file))) {return ""; }
    my $obj_fh = Archive::Zip::MemberRead->new($obj_zip, $xlsx_file);
    if (! defined($obj_fh)) {return ""; }
    my $line;
    my $doc_cont = '';
    while (defined($line = $obj_fh->getline())) {$doc_cont .= $line; }

    my $obj_dom = new XML::DOM::Parser;
    my $obj_doc = $obj_dom->parse($doc_cont);
    if (! defined($obj_doc)) {return ""; }
    my $nodes = $obj_doc->getElementsByTagName('t');
    if (! defined($nodes)) {return ""; }
    my $node_cnt = $nodes->getLength;
    my $node_obj;
    for (my $node_id = 0; $node_id < $node_cnt; $node_id ++) {
        if (defined($node_obj = $nodes->item($node_id)->getFirstChild())) {
            $dump_text .= $node_obj->getData();
            $dump_text .= ' ';
        }
    }
    return $dump_text;
}

1;

