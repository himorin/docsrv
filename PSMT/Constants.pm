# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Module for Constants Definitions
#
# Copyright (C) 2010 - : JPMOZ contributors
# License: GPL, MPL (dual)
# Contributor(s):
#   Atsushi Shimono <shimono@bug-ja.org>

# modified Jpmoz -> PSMT

package PSMT::Constants;

use strict;

use base qw(Exporter);
use File::Basename;
use Cwd;

@PSMT::Constants::EXPORT = qw(
  PSMT_DOCSRV_VERSION

  HEADER_LINKS
  AVAIL_FORMATS
  LOCATIONS

  TRUE
  FALSE

  contenttypes
  SAFE_PROTOCOLS
  DB_MODULE

  DB_UNLOCK_ABORT
);

use constant TRUE         => 1;
use constant FALSE        => 0;

use constant PSMT_DOCSRV_VERSION => "0.1";

use constant HEADER_LINKS => (
  'index', 'dir', 'labels', 'favs'
);

use constant AVAIL_FORMATS => {
  'docadd'             => ['html'],
  'docfav'             => ['html', 'json'],
  'docinfo'            => ['html'],
  'docupdate'          => ['html'],
  'favlist'            => ['html'],
  'fileinfo'           => ['html'],
  'index'              => ['html'],
  'labellist'          => ['html'],
  'pathgroup'          => ['html'],
  'pathinfo'           => ['html'],

  'error/code'         => ['html', 'json'],
  'error/user'         => ['html', 'json'],

  'favorite/table'     => ['html'],

  'global/footer'      => ['html'],
  'global/header'      => ['html'],
};

use constant contenttypes =>
  {
    "html" => "text/html" ,
    "txt"  => "text/plain" ,
    "pdf"  => "application/pdf" ,
    "rdf"  => "application/rdf+xml" ,
    "atom" => "application/atom+xml" ,
    "xml"  => "application/xml" ,
    "js"   => "application/x-javascript" ,
    "csv"  => "text/csv" ,
    "jpg"  => "image/jpeg" ,
    "gif"  => "image/gif" ,
    "png"  => "image/png" ,
    "ics"  => "text/calendar" ,
    "default" => 'application/octet-stream',
  };

use constant SAFE_PROTOCOLS => (
  'ftp', 'http', 'https', 'irc', 'view-source',
);

use constant DB_MODULE => {
    'mysql'   => {
        db   => 'PSMT::DB::Mysql',
        dbd  => 'DBD::mysql',
        name => 'MySQL',
    },
};

# DB
use constant DB_UNLOCK_ABORT => 1;

# installation locations
# parent
#  => <installation>/ : script installation (like public_html)
#  => data/ : data storage
#    => cache/ : Perl TT cache
sub LOCATIONS {
    # absolute path for installation ("installation")
    my $inspath = dirname(dirname($INC{'PSMT/Constants.pm'}));
    # detaint
    $inspath =~ /(.*)/;
    $inspath = $1;
    if ($inspath eq '.') {
       $inspath = getcwd();
    }
    my $datapath = "$inspath/data";

    return {
        'install'     => $inspath,
        'cgi_path'    => $inspath,
        'rel_tmpl'    => './tmpl/',
        'templates'   => "$inspath/tmpl",
        'datadir'     => $datapath,
        'datacache'   => "$datapath/cache",
    };
}


1;

__END__

