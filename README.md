# zimbra export accounts
NB! Provided as is, with no warranty.

Run the script as zimbra user;
USAGE: zimbra_export_accounts.sh /my/path

It takes the list of domains to select account from (one domain per launch); generates import script mydomain.com_importuserinfo.sh (non-executable).

If you choose to export mailboxes contents, it also generates mydomain.com_import_mailbox_contents.sh script and archives mailboxes at *.tar.gz's as well (to /my/path).

Non-english ops, take care of locale before running mydomain.com_importuserinfo.sh, for example:
```export LC_ALL='ru_RU.UTF-8'```
Spend time to check these files' contents before. Run them at new server by zimbra user. Good luck!
