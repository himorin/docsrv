You need the following softwares.
* MySQL server (or its compatible)
* Perl (TemplateToolkit, Email::Send, Net::LDAP, Archive::Zip, XML::DOM)
* Apache (LDAP auth)
* HyperEstraier (with perl binding libraries)

Installation procedure

1. run config_test.pl : Will create data/params
2. Edit data/params with suitable directories and settings
3. Create MySQL database
4. Import database table definitions - common.sql
5. Import initial configuration parameters - docsrv_config.sql

Reamrks and Notes
* Database of HyperEstraier will be initialized automatically
* Hash directories will be created by software
* DAV area will be used as temporary storage, too

Apache Alias for query path
* Alias <base_uri>/path/ <dir>/pathinfo.cgi/
* Alias <base_uri>/doc/  <dir>/docinfo.cgi/

