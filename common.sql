-- CREATE DATABASE docsrv DEFAULT CHARACTER SET utf8;


CREATE TABLE activity (
  uname         text                 NOT NULL                            ,
  fileid        text                 NOT NULL                            ,
  dltime        datetime             NOT NULL                            ,
  srcip         int         UNSIGNED NOT NULL                            
);

CREATE TABLE docinfo (
  fileid        text                 NOT NULL                            ,
  fileext       text                 NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            ,
  uptime        datetime             NOT NULL                            ,
  uname         text                 NOT NULL                            ,
  srcip         int         UNSIGNED NOT NULL                            ,
  description   text                     NULL                            
);

CREATE TABLE path (
  pathid        int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  parent        int         UNSIGNED NOT NULL                            ,
  pathname      text                 NOT NULL                            ,
  description   text                     NULL                            
);

CREATE TABLE docreg (
  docid         int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  pathid        int         UNSIGNED NOT NULL                            ,
  filename      text                 NOT NULL                            ,
  description   text                     NULL                            
);

CREATE TABLE access_path (
  pathid        int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
);

CREATE TABLE deny_file (
  pathid        int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
);

CREATE TABLE label (
  labelid       int         UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY ,
  name          text                 NOT NULL                            ,
  description   text                     NULL                            
);

CREATE TABLE label_doc (
  labelid       int         UNSIGNED NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            
);

CREATE TABLE access_label (
  labelid       int         UNSIGNED NOT NULL                            ,
  gname         text                 NOT NULL                            
);

CREATE TABLE favorite (
  uname         text                 NOT NULL                            ,
  docid         int         UNSIGNED NOT NULL                            
);


