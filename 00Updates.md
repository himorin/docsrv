# 0.6

* Replaced Search function
* UI tweaks
* Added new UI configuration parameter: table.preview, table.nopreview
* Added new configuration parameter: cl_user, libreoffice, imagemagick
* Added hash check (SHA512) on upload
* Added preview for ODF, OOXML, FITS

# 0.5.7

* Replaced FullSearchHE to FullSearchMroonga
* Added new table for full text search - fullindex

# 0.5.6

* Renamed HyperEstraier modules to FullSearch*
* Fixed xml parse handling error on FullSearch/*
* Extended .zip download
* Added tablesort
* Added jQuery, under migration from YUI to jQuery

# 0.5.5

* Added popup feature via path/document icon

# 0.5.4

* Added Markdown into path/document description
    * previous short description will be "first line"

# 0.5.3

* Added security flag (encrypted download) for document
* Added file viewer mode (not download, just show) for specified MIME type
* Fixed issue on command not found in filters before HE

