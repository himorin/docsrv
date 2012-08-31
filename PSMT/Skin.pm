# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for - Skin, icon manipulation
#
# Copyright (C) 2011 - : nano-opt
# Contributor(s):
#   Atsushi Shimono <shimono@nano-opt.jp>

package PSMT::Skin;

use strict;

use base qw(Exporter);

use PSMT::DB;
use PSMT::Constants;
use PSMT::Util;

%PSMT::Skin::EXPORT = qw(
    new

    ListIconsTable
    ListIconsMime

    ListAvailFiles

    UpdateIcon
    GetIconInfo
);

# ListEntriesForHeader

sub new {
    my ($self) = @_;
    return $self;
}

sub ListIconsTable {
    my ($self, $enabled) = @_;
    return $self->ListEntriesForHeader('table.', $enabled);
}

sub ListIconsMime {
    my ($self, $enabled) = @_;
    return $self->ListEntriesForHeader('mime.', $enabled);
}

sub ListAvailFiles {
    my ($self) = @_;
    my $root = PSMT::Constants::LOCATIONS()->{skins} . '/images';
    my (@path, @files, $target, $cur_dir);
    push(@path, $root);
    while ($#path > -1) {
        $target = shift(@path);
        $cur_dir = $target;
        if ($cur_dir =~ /^$root\/(.*)$/g) {$cur_dir = $1; }
        opendir(TDIR, $target);
        foreach (readdir(TDIR)) {
            if (substr($_, 0, 1) eq '.') {next; }
            if (-d "$target/$_") {
                push(@path, "$target/$_");
                next;
            }
            push(@files, $cur_dir . '/' . $_);
        }
        closedir(TDIR);
    }
    return \@files;
}

sub CheckIconExist {
    my ($self, $file) = @_;
    my $path = PSMT::Constants::LOCATIONS()->{skins} . '/images/' . $file;
    if (! -f $path) {return FALSE; }
    return TRUE;
}

sub UpdateIcon {
    my ($self, $class, $target, $tip, $file, $enable) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('disp_skin WRITE');
    if (defined($self->GetIconInfo($class, $target))) {
        my $sth = $dbh->prepare('UPDATE disp_skin SET value = ?, tiphelp = ?, enabled = ? WHERE name = ?');
        if ($sth->execute($file, $tip, $enable, $class . '.' . $target) == 0) {
            PSMT->template->set_vars('Skin::UpdateIcon');
            PSMT::error->throw_error_code('invalid_parameter');
        }
    } else {
        my $sth = $dbh->prepare('INSERT INTO disp_skin (name, value, tiphelp, enabled) VALUES (?, ?, ?, ?)');
        if ($sth->execute($class . '.' . $target, $file, $tip, $enable) == 0) {
            PSMT->template->set_vars('Skin::UpdateIcon');
            PSMT::error->throw_error_code('invalid_parameter');
        }
    }
    $dbh->db_unlock_tables();
}

sub GetIconInfo {
    my ($self, $class, $target) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('disp_skin READ');
    my $sth = $dbh->prepare('SELECT * FROM disp_skin WHERE name = ?');
    $sth->execute($class . '.' . $target);
    if ($sth->rows() != 1) {return undef; }
    return $sth->fetchrow_hashref();
}

#--------------------------------------------------------------------- private

sub ListEntriesForHeader {
    my ($self, $head, $enable) = @_;
    my $dbh = PSMT->dbh;
    $dbh->db_lock_tables('disp_skin READ');
    my $len = length($head);
    if ($len == 0) {return undef; }
    my ($sth, %ret, $ref);
    if (defined($enable)) {
      $sth = $dbh->prepare(
          'SELECT SUBSTR(name, ?) AS title, value, tiphelp, enabled
           FROM disp_skin
           WHERE SUBSTR(name, 1, ?) = ? AND enabled = ?
           ORDER BY name ASC');
      $sth->execute($len + 1, $len, $head, $enable);
    } else {
      $sth = $dbh->prepare(
          'SELECT SUBSTR(name, ?) AS title, value, tiphelp, enabled
           FROM disp_skin
           WHERE SUBSTR(name, 1, ?) = ?
           ORDER BY name ASC');
      $sth->execute($len + 1, $len, $head);
    }
    while ($ref = $sth->fetchrow_hashref()) {
        $ret{$ref->{'title'}} = $ref;
    }
    return \%ret;
}



1;

__END__


