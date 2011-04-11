CREATE TABLE activity (
  uname         text                 NOT NULL                            ,
  fileid        text                 NOT NULL                            ,
  when          datetime             NOT NULL                            ,
  srcip         int         UNSIGNED NOT NULL                            
);

CREATE TABLE docinfo (
  fileid        text                 NOT NULL                PRIMARY KEY ,
  docid         int         UNSIGNED NOT NULL                            ,
  when          datetime             NOT NULL                            ,
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


