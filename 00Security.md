Document server security model

# Check security group

## admin

Use PSMT::User::is_inadmin(), admin if TRUE returned.

# Document Security flag

## definition

"doc_reg.secure" is the flag, default is 0, if 1 then secure document.
For secure document, download will be passworded zip.
This flag is "document" basis, but not "file".

## Set

* initial document registration : anyone can set flag
* add file to existing document : no change allowed
* modify flag of existing document : allowed only by admin



