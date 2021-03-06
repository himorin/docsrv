# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Search
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Search;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;
use PSMT::Label;
use PSMT::Access;
use PSMT::File;

%PSMT::Search::EXPORT = qw(
    new

    SearchDoc
    RecentUpdate
);

sub new {
    my ($self) = @_;
    return $self;
}

sub RecentUpdate {
    my ($self, $days) = @_;
    if ($days == 0) {return undef; }
    $days = - $days;
    my ($sql);
    $sql =
        'SELECT docreg.docid
         FROM docreg
         LEFT JOIN docinfo ON docreg.docid = docinfo.docid
         WHERE docinfo.uptime > ADDDATE(NOW(), ?)
               AND docinfo.enabled = 1
         GROUP BY docreg.docid
         ORDER BY docinfo.uptime DESC
        ';
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute($days);
    my $dret = $sth->fetchall_hashref('docid');
    my @dids = keys(%$dret);
    if ($#dids < 0) {return undef; }
    return PSMT::File->GetDocsInfo(\@dids);
}

sub SearchDoc {
    my ($self, $conf, $cond) = @_;
    my ($sql, @data);
    $sql =
        'SELECT docreg.docid
         FROM docreg
         LEFT JOIN label_doc ON docreg.docid = label_doc.docid
         WHERE 
        ';
    my ($arr, $cond, $app);
    $app = FALSE;
    $cond = $self->Cond($cond);
    if (defined($conf->{docreg_desc})) {
        $arr = $conf->{docreg_desc};
        $cond = $conf->{docreg_desc_cond};
        if ($app) {$sql .= $cond; }
        $sql .= $self->SQLCondLike('docreg.description', $arr, $cond, \@data);
        $app = TRUE;
    }
    if (defined($conf->{doc_label})) {
        $arr = $conf->{doc_label};
        $cond = $conf->{doc_label_cond};
        if ($app) {$sql .= $cond; }
        $sql .= $self->SQLCondEq('label_doc.labelid', $arr, $cond, \@data);
        $app = TRUE;
    }
    if ($#data == -1) {return undef; }
    $sql .= ' GROUP BY docreg.docid';
    my $dbh = PSMT->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@data);
    if ($sth->rows() == 0) {return undef; }
    my ($ref, @res);
    foreach ($ref = $sth->fetchrow_hashref()) {push(@res, $ref->{docid}); }
    return \@res;
}

################################################################## PRIVATE

sub Cond {
    my ($self, $cond) = @_;
    if ((! defined($cond)) || (lc($cond) ne 'and')) {return 'OR'; }
    return 'AND';
}

sub SQLCondLike {
    my ($self, $col, $arr, $cond, $sth) = @_;
    my ($sql, $app);
    $cond = $self->Cond($cond);
    $app = FALSE;
    foreach (@$arr) {
        if ($app) {$sql .= $cond; }
        $sql .= ' ' . $col . ' LIKE ? ';
        $app = TRUE;
        push(@$sth, '%' . $_ . '%');
    }
    return ' (' . $sql . ') ';
}

sub SQLCondEq {
    my ($self, $col, $arr, $cond, $sth) = @_;
    my ($sql, $app);
    $cond = $self->Cond($cond);
    $app = FALSE;
    foreach (@$arr) {
        if ($app) {$sql .= $cond; }
        $sql .= ' ' . $col . ' = ? ';
        $app = TRUE;
        push(@$sth, $_);
    }
    return ' (' . $sql . ') ';
}


1;

__END__


