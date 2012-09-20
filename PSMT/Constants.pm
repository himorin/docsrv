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
  HE_FILE_FILTER
  HE_FILE_FILTER_INTERNAL

  TRUE
  FALSE

  contenttypes
  SAFE_PROTOCOLS
  DB_MODULE

  DB_UNLOCK_ABORT
);

use constant TRUE         => 1;
use constant FALSE        => 0;

use constant PSMT_DOCSRV_VERSION => "0.5.2";

use constant HEADER_LINKS => (
  'dir', 'index', 'add', 'labels', 'favs', 'recent', 'search', 'admin', 'config'
);

use constant AVAIL_FORMATS => {
  'admin'              => ['html'],
  'config'             => ['html'],
  'docadd'             => ['html'],
  'docfav'             => ['html', 'json'],
  'docgroup'           => ['html'],
  'docinfo'            => ['html'],
  'doclabel'           => ['html'],
  'docupdate'          => ['html'],
  'favlist'            => ['html'],
  'fileinfo'           => ['html', 'json'],
  'index'              => ['html'],
  'json'               => ['html', 'json', 'js'],
  'labeledit'          => ['html'],
  'labellist'          => ['html'],
  'pathadd'            => ['html'],
  'pathgroup'          => ['html'],
  'pathinfo'           => ['html'],
  'recent'             => ['html'],

  'attribute/list'     => ['html', 'json'],
  'attribute/get'      => ['html', 'json'],
  'attribute/add'      => ['html', 'json'],
  'attribute/update'   => ['html', 'json'],

  'search/query'       => ['html'],
  'search/search'      => ['html'],

  'email/newdoc'       => ['email'],
  'email/newfile'      => ['email'],
  'email/newpath'      => ['email'],

  'error'              => ['html', 'json'],
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

use constant INVALID_NAME_CHAR => '[\\/\\?\\*\\\\]';

use constant contenttypes =>
  {
    "html" => "text/html" ,
    "txt"  => "text/plain" ,
    "pdf"  => "application/pdf" ,
    "rdf"  => "application/rdf+xml" ,
    "atom" => "application/atom+xml" ,
    "xml"  => "application/xml" ,
    "js"   => "application/javascript" ,
    "json" => "application/json" ,
    "csv"  => "text/csv" ,
    "jpg"  => "image/jpeg" ,
    "gif"  => "image/gif" ,
    "png"  => "image/png" ,
    "ics"  => "text/calendar" ,
    "default" => 'application/octet-stream',
  };

use constant HE_FILE_FILTER_INTERNAL => 'INTERNAL';
use constant HE_FILE_FILTER => {
  'pdf'    => '/usr/bin/pdftotext -enc UTF-8',
  'txt'    => '/usr/bin/lv -Ou8',
  'tex'    => '/usr/bin/untex -m -e - | /usr/bin/lv -Ou8',
  'doc'    => '/usr/bin/wvWare -c utf8 -1 -x /usr/share/wv/wvText.xml',
  'docx'   => HE_FILE_FILTER_INTERNAL,
  'ppt'    => '/usr/bin/ppthtml',
  'pptx'   => HE_FILE_FILTER_INTERNAL,
  'xlsx'   => HE_FILE_FILTER_INTERNAL,
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

