# System Requirements

You need the following softwares.

* MySQL server (or its compatible)
* Perl
    * TemplateToolkit
    * Email::Send
    * Net::LDAP
    * Archive::Zip
    * XML::DOM
    * Text::Markdown
* Apache (with LDAP auth)
* HyperEstraier (with perl binding libraries)

# Installation procedure

1. run config_test.pl : Will create data/params
2. Edit data/params with suitable directories and settings
3. Create MySQL database
4. Import database table definitions - common.sql
5. Import initial configuration parameters - docsrv_config.sql

# Reamrks and Notes

* Database of HyperEstraier will be initialized automatically
* Hash directories will be created by software
* DAV area will be used as temporary storage, too

# Apache Alias for query path

* Alias <base_uri>/path/ <dir>/pathinfo.cgi/
* Alias <base_uri>/doc/  <dir>/docinfo.cgi/

# UPGRADE NOTES

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

