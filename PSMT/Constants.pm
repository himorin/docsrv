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

  INVALID_NAME_CHAR

  TRUE
  FALSE

  contenttypes
  SAFE_PROTOCOLS
  DB_MODULE

  DB_UNLOCK_ABORT
);

use constant TRUE         => 1;
use constant FALSE        => 0;

use constant PSMT_DOCSRV_VERSION => "0.2.0";

use constant HEADER_LINKS => (
  'index', 'dir', 'labels', 'favs', 'search'
);

use constant AVAIL_FORMATS => {
  'docadd'             => ['html'],
  'docfav'             => ['html', 'json'],
  'docinfo'            => ['html'],
  'doclabel'           => ['html'],
  'docupdate'          => ['html'],
  'favlist'            => ['html'],
  'fileinfo'           => ['html'],
  'index'              => ['html'],
  'labeledit'          => ['html'],
  'labellist'          => ['html'],
  'pathadd'            => ['html'],
  'pathgroup'          => ['html'],
  'pathinfo'           => ['html'],

  'search/query'       => ['html'],
  'search/search'      => ['html'],

  'error/code'         => ['html', 'json'],
  'error/user'         => ['html', 'json'],

  'favorite/table'     => ['html'],

  'global/footer'      => ['html'],
  'global/header'      => ['html'],

  'skins/index'             => ['html'],
  'skins/list'              => ['html'],
  'skins/list_new'          => ['html'],
  'skins/select_target'     => ['html'],
};

use constant INVALID_NAME_CHAR => '\/\?\*\\';

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
        'skins'       => "$inspath/skins",
        'datadir'     => $datapath,
        'datacache'   => "$datapath/cache",
    };
}


1;

__END__

