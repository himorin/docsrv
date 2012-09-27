-- CREATE DATABASE docsrv DEFAULT CHARACTER SET utf8;

/*

access_label : deleted at rev.114
access_doc   : added at rev.114

attr_path : added at rev.146
attr_doc  : added at rev.146
attr_file : added at rev.146

*/

CREATE TABLE activity (
  uname         text                 NOT NULL                            ,
  fileid        text                 NOT NULL                            ,
  dltime        datetime             NOT NULL                            ,
  srcip         int         UNSIGNED NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE docinfo (
  fileid        text                 NOT NULL                            ,
  fileext       text                 NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            ,
  uptime        datetime             NOT NULL                            ,
  uname         text                 NOT NULL                            ,
  srcip         int         UNSIGNED NOT NULL                            ,
  description   text                     NULL                            ,
  enabled       int                  NOT NULL DEFAULT 1                  
) DEFAULT CHARSET=utf8 ;

CREATE TABLE path (
  pathid        int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  parent        int         UNSIGNED NOT NULL                            ,
  pathname      text                 NOT NULL                            ,
  description   text                     NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE docreg (
  docid         int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  pathid        int         UNSIGNED NOT NULL                            ,
  filename      text                 NOT NULL                            ,
  description   text                     NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE access_path (
  pathid        int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE deny_file (
  pathid        int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE label (
  labelid       int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  name          text                 NOT NULL                            ,
  description   text                     NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE label_doc (
  labelid       int         UNSIGNED NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            
) DEFAULT CHARSET=utf8 ;

/*
CREATE TABLE access_label (
  labelid       int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
) DEFAULT CHARSET=utf8 ;
*/

CREATE TABLE favorite (
  uname         text                 NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE fav_path (
  uname         text                 NOT NULL                            ,
  pathid        int         UNSIGNED NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE disp_skin (
  name          varchar(64)          NOT NULL                PRIMARY KEY ,
  value         varchar(255)         NOT NULL                            ,
  tiphelp       varchar(255)             NULL                            ,
  enabled       tinyint     UNSIGNED NOT NULL DEFAULT 0                  
) DEFAULT CHARSET=utf8 ;

CREATE TABLE setting (
  name          varchar(64)          NOT NULL                            ,
  default_value varchar(64)          NOT NULL                            ,
  class         varchar(16)          NOT NULL                            ,
  enumval       varchar(255)             NULL                            ,
  enabled       tinyint     UNSIGNED NOT NULL DEFAULT 0                  
) DEFAULT CHARSET=utf8 ;

CREATE TABLE profiles (
  uname         varchar(64)          NOT NULL                            ,
  name          varchar(64)          NOT NULL                            ,
  value         varchar(64)          NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE access_doc (
  docid         int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE attr_path (
  id            int         UNSIGNED NOT NULL                            ,
  attr          varchar(64)          NOT NULL                            ,
  value         varchar(255)             NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE attr_doc (
  id            int         UNSIGNED NOT NULL                            ,
  attr          varchar(64)          NOT NULL                            ,
  value         varchar(255)             NULL                            
) DEFAULT CHARSET=utf8 ;

CREATE TABLE attr_file (
  id            int         UNSIGNED NOT NULL                            ,
  attr          varchar(64)          NOT NULL                            ,
  value         varchar(255)             NULL                            
) DEFAULT CHARSET=utf8 ;


