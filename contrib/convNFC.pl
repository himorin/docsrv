#! /usr/bin/perl

use strict;
use Unicode::Normalize;

use PSMT;
use PSMT::Constants;
use PSMT::DB;

# check existing name of path, document; convert to NFC

my @dbh_likes = ("X'25E3829925'", "X'25E3829A25'");

my $dbh = PSMT->dbh;
my ($sql, $sth, %list, $ref);

# 1st, docreg
$dbh->db_lock_tables('docreg READ');
$sql = 'SELECT docid, filename FROM docreg WHERE filename LIKE ' . 
       join(" OR filename LIKE ", @dbh_likes);
$sth = $dbh->prepare($sql);
$sth->execute();
while ($ref = $sth->fetchrow_hashref()) {
    $list{$ref->{docid}} = Unicode::Normalize::NFC($ref->{filename});
}

$dbh->db_lock_tables('docreg WRITE');
$sql = 'UPDATE docreg SET filename = ? WHERE docid = ?';
$sth = $dbh->prepare($sql);
foreach (keys %list) {
    if ($sth->execute($list{$_}, $_) == 0) {
        print "Error: docreg ID = $_ (filename = \"$list{$_}\")\n";
    }
}

%list = ();
# 2nd, path
$dbh->db_lock_tables('path READ');
$sql = 'SELECT pathid, pathname FROM path WHERE pathname LIKE ' .
       join(" OR pathname LIKE ", @dbh_likes);
$sth = $dbh->prepare($sql);
$sth->execute();
while ($ref = $sth->fetchrow_hashref()) {
    $list{$ref->{pathid}} = Unicode::Normalize::NFC($ref->{pathname});
}

$dbh->db_lock_tables('path WRITE');
$sql = 'UPDATE path SET pathname = ? WHERE pathid = ?';
$sth = $dbh->prepare($sql);
foreach (keys %list) {
    if ($sth->execute($list{$_}, $_) == 0) {
        print "Error: path ID = $_ (pathname = \"$list{$_}\")\n";
    }
}

exit;

