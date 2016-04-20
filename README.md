# System Requirements

You need the following softwares.

* MySQL server (or its compatible)
    * Mroonga engine
* Perl
    * TemplateToolkit
    * Email::Send
    * MIME::Types
    * Net::LDAP
    * Archive::Zip
    * XML::DOM
    * Text::Markdown
    * Digest::SHA
* Zip (executable; for security flagged file download)
* Apache (with LDAP auth)
* LibreOffice (for ms-office and OOXML preview)
* ImageMagick (for FITS to PNG)

# Installation procedure

1. run config_test.pl : Will create data/params
2. Edit data/params with suitable directories and settings
3. Create MySQL database
4. Import database table definitions - common.sql
5. Import initial configuration parameters - docsrv_config.sql

## Reamrks and Notes

* Hash directories will be created by software
* DAV area will be used as temporary storage, too

## Apache Alias for query path

* Alias <base_uri>/path/ <dir>/pathinfo.cgi/
* Alias <base_uri>/doc/  <dir>/docinfo.cgi/

## Configuration after installation (data/params)

* admin_email ; Administrator email to be dispayed
* admingroup ; LDAP Group who are marked site admin
* base_uri : URI base of installation
* cl_user: user name for command line (non authed CGI)
* cookie_domain : cookie domain restriction if need to restrict
* cookie_expires : default cookie expire period
* cookie_path : cookie path if need to restrict
* dav_path : data temporary uploaded target directory
* dav_uri : WebDAV URI for use to upload
* db_driver : DB driver name
* db_err_maxlen : Max error string length to be displayed on error
* db_host : DB host name
* db_name : DB name
* db_pass : DB password
* db_port : DB port to access
* db_sock : DB local sock file name
* db_user : DB user
* email_lang : Default language for email
* file_path : Files to be stored
* hash_depth : Hash directory depth to store files
* imagemagick : (full) path to convert (imagemagick) command
* ldap_basedn : LDAP base dn
* ldap_uri : LDAP URI
* libreoffice : (full) path to libreoffice binary
* view_mime : MIME type to be used for browser display ('image' by default)

# UPGRADE NOTES

## To 0.6 from 0.5.7

* New perl module required: MIME::Types
* Require Mroonga extension for MariaSQL server
* One table modified: docinfo
* New parameters added: libreoffice, imagemagick

## To 0.5.7 from 0.5.6

* YUI has removed, and changed into jQuery

## To 0.5.6 from 0.5.5

* Fulltext index replaced with Groonga (or MariaDB port - mroonga)
    * New table added, index need to be re-created by cl_add_ext.pl

## To 0.5.4 from prior

* Require new Perl module: Text::Markdown

## To 0.5.3 from prior

* One table added: 'attribute'.
* One table modified: 'doc_reg.secure'.
* This table should be created by hand. (refer common.sql for schema)
* One disp_skin added: 'table.attribute' (refer docsrv_config.sql for data)
* view_mime parameter added (rev. 173)

## To 0.5.2 from prior

* 'access_label' table droped and migrated into 'access_doc'.
* This operation should be performed by hand.
