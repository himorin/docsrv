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
  PATH_SP_ZIPADD

  INVALID_NAME_CHAR
  INVALID_HEAD_TAIL
  HE_FILE_FILTER
  HE_FILE_FILTER_INTERNAL

  TRUE
  FALSE

  DEF_CONTENTTYPE
  IS_PREVIEW
  SAFE_PROTOCOLS
  DB_MODULE
  OOXML_OPT
  OOXML_CONV_TO

  DB_UNLOCK_ABORT

  HASH_SIZE
  HASH_LEN
);

use constant TRUE         => 1;
use constant FALSE        => 0;

use constant PSMT_DOCSRV_VERSION => "0.6";

use constant HEADER_LINKS => (
  'dir', 'index', 'add', 'labels', 'favs', 'recent', 'search', 'admin', 'config'
);

use constant AVAIL_FORMATS => {
  'admin'              => ['html'],
  'config'             => ['html'],
  'delpath'            => ['html'],
  'docadd'             => ['html'],
  'docfav'             => ['html', 'json'],
  'docgroup'           => ['html'],
  'docinfo'            => ['html'],
  'doclabel'           => ['html'],
  'docmerge'           => ['html'],
  'docupdate'          => ['html'],
  'favlist'            => ['html'],
  'fileinfo'           => ['html', 'json'],
  'hashcheck'          => ['html'],
  'index'              => ['html'],
  'labeledit'          => ['html'],
  'labellist'          => ['html'],
  'pathadd'            => ['html'],
  'pathgroup'          => ['html'],
  'pathinfo'           => ['html'],
  'preview'            => ['html'],
  'recent'             => ['html'],
  'zipadd'             => ['html'],
  'zipadd-confirm'     => ['html'],
  'zipadd-fail'        => ['html'],

  'attribute/list'     => ['html', 'json'],
  'attribute/get'      => ['html', 'json'],
  'attribute/add'      => ['html', 'json'],
  'attribute/update'   => ['html', 'json'],
  'attribute/search'   => ['html', 'json'],

  'search/query'       => ['html'],
  'search/search'      => ['html'],

  'email/newdoc'       => ['email'],
  'email/newfile'      => ['email'],
  'email/newpath'      => ['email'],
  'email/pass'         => ['email'],

  'error'              => ['html', 'json'],
  'error/code'         => ['html', 'json'],
  'error/user'         => ['html', 'json'],

  'favorite/table'     => ['html'],

  'global/footer'      => ['html'],
  'global/header'      => ['html'],

  'json/docinfo'       => ['html'],
  'json/loaddoc'       => ['html'],
  'json/loadfile'      => ['html'],
  'json/pathinfo'      => ['html'],
  'json/table'         => ['html'],

  'skins/index'             => ['html'],
  'skins/list'              => ['html'],
  'skins/list_new'          => ['html'],
  'skins/select_target'     => ['html'],
};

use constant INVALID_NAME_CHAR => '[\\/\\?\\*\\\\]';
use constant INVALID_HEAD_TAIL => ' ._';

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

use constant DEF_CONTENTTYPE => 'application/octet-stream';
use constant IS_PREVIEW => { 
  'image/fits' => 'fits',
  'image/'   => 'image',
  'application/pdf' => 'viewerjs',
  'application/vnd.oasis.opendocument.' => 'viewerjs',
  'application/vnd.openxmlformats-officedocument.' => 'libreoffice',
  'application/msword' => 'libreoffice',
  'application/vnd.ms-word' => 'libreoffice',
  'application/vnd.ms-excel' => 'libreoffice',
  'application/vnd.ms-powerpoint' => 'libreoffice',
};
use constant OOXML_OPT => '--headless --convert-to {ext} --outdir {dir}';
use constant OOXML_CONV_TO => {
  'pptx'   => 'odp',
  'sldx'   => 'odp',
  'ppsx'   => 'odp',
  'potx'   => 'otp',
  'xlsx'   => 'ods',
  'xltx'   => 'ots',
  'docx'   => 'odt',
  'dotx'   => 'ott',
  'doc'    => 'odt',
  'dot'    => 'ott',
  'docm'   => 'odt',
  'dotm'   => 'ott',
  'xls'    => 'ods',
  'xlb'    => 'ods',
  'xlt'    => 'ots',
  'xlsb'   => 'ods',
  'xlsm'   => 'ods',
  'ppt'    => 'odp',
  'pps'    => 'odp',
  'pptm'   => 'odp',
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

# SHA hash
use constant HASH_SIZE => 512;
use constant HASH_LEN  => 86;

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
        'zipcache'    => "$datapath/dwez",
        'rel_zipcache' => './data/dwez',
    };
}
use constant PATH_SP_ZIPADD => 'zipadd/';


1;

__END__

