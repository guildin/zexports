#!/bin/bash

#file: zimbra_export_accounts.sh
#account export: parses import script for account, password, Name, SN, DisplayName, mail forward, aliases
#mailbox export: exports data and parses import script
#created by guildin
#version 0.9
#date: 2019-01-02
#prepare: chmod 750 zimbra_export_accounts.sh && chown zimbra:zimbra zimbra_export_accounts.sh
#run:     zimbra@myhost:~$ zimbra_export_accounts.sh /my/path


if [[ $# -eq 0 ]] ; then
    echo 'USAGE: zimbra_export_accounts.sh /my/path'
    exit 1
    else 
    echo "Will dump mail boxes to $1 ..."
fi



ZDUMPDIR=$1
ZMBOX=/opt/zimbra/bin/zmmailbox
if [ ! -d $ZDUMPDIR ]; then
echo "...Creating $ZDUMPDIR"
mkdir -p $ZDUMPDIR
fi
	echo "Checking for domains. A moment, please..."
	#Getting Domains List to select.
	PS3='===Choose domain to export accounts. Choose cancel to exit. '
	select domainName in  `zmprov gad` 'Cancel'
	do
		if [ $domainName = 'Cancel' ] 
		then
			echo "Exiting..."
			exit 0
		else
			DomainSelected=$domainName
			break
		fi
	done
        #Getting Domains List to select.
        PS3='===Would you like to export mailbox contents? It can take a long time '
	ArchiveMBox="Yes No Cancel"
        select exportOptions in $ArchiveMBox
        do
		case $exportOptions in
			"Yes" )
				DoArchiveMBox=true
				break
				;;
			"No" )
				break
				;;
			"Cancel" )
                        	echo "Exiting..."
	                        exit 0
				;;
		esac
        done

	echo "Starting export $DomainSelected. Executing zmprov..."
	echo "printf '=== Importing accounts at $DomainSelected ===\n\n'" >> $ZDUMPDIR/parsingAccDataImport.txt
	for mbox in `zmprov -l gaa $DomainSelected`
        do
		if [ $mbox == "galsync@"$DomainSelected ]; then echo "skipping mailbox galsync@"$DomainSelected; continue; fi #dumb check for galsync account that has no password
        	printf "Processing $mbox ..."
#	download user data. Can take a looong time.
		if [ $DoArchiveMBox ]; then printf "Archiving $mbox ..."; $ZMBOX -z -m $mbox -t 0 getRestURL "//?fmt=tgz" > $ZDUMPDIR/$mbox.tgz; fi
		printf " Getting data... "
		zmprov ga $mbox > $ZDUMPDIR/gettingAccData.txt
#	account settings
		getName=`cat $ZDUMPDIR/gettingAccData.txt | grep givenName | sed 's/givenName:\ /givenName\ \x27/g' | sed 's/$/\x27/g'`
		getSN=`cat $ZDUMPDIR/gettingAccData.txt | grep sn | sed 's/sn:\ /sn\ \x27/g' | sed 's/$/\x27/g'`
		getDisplayName=`cat $ZDUMPDIR/gettingAccData.txt | grep displayName | sed 's/displayName:\ /displayName\ \x27/g' | sed 's/$/\x27/g'`
		getPassword=`cat $ZDUMPDIR/gettingAccData.txt | grep userPassword | sed 's/userPassword:\ /userPassword\ \x27/g' | sed 's/$/\x27/g'`
		getForwardingAddress=`cat $ZDUMPDIR/gettingAccData.txt | grep 'zimbraPrefMailForwardingAddress' | sed 's/zimbraPrefMailForwardingAddress: //'`
		getAlias=`cat $ZDUMPDIR/gettingAccData.txt | grep 'zimbraMailAlias'`
		echo "printf 'creating $mbox... \n'" >> $ZDUMPDIR/parsingAccDataImport.txt
		echo "zmprov ca $mbox password" >> $ZDUMPDIR/parsingAccDataImport.txt
		echo "printf 'Setting up $mbox...'" >> $ZDUMPDIR/parsingAccDataImport.txt
		echo "zmprov ma $mbox $getName $getSN $getDisplayName $getPassword" >> $ZDUMPDIR/parsingAccDataImport.txt
		if [ "$getForwardingAddress" != "" ]; then echo "zmprov ma $mbox zimbraPrefMailForwardingAddress $getForwardingAddress" >> $ZDUMPDIR/parsingAccDataImport.txt ; fi
		printf '%s ' "${getAlias[@]}" | sed -r 's/zimbraMailAlias: /zmprov aaa '$mbox' /' >> $ZDUMPDIR/parsingAccDataImport.txt
		printf '\n' >> $ZDUMPDIR/parsingAccDataImport.txt
		echo "printf ' done.\n'" >> $ZDUMPDIR/parsingAccDataImport.txt
		echo $mbox >> $ZDUMPDIR/gettingAccList.txt
		printf "OK!\n"
        done
        echo "printf '=== Import of accounts at $DomainSelected completed ===\n'" >> $ZDUMPDIR/parsingAccDataImport.txt
#cleaning_up account data temporary files
mv $ZDUMPDIR/parsingAccDataImport.txt $ZDUMPDIR/$DomainSelected"_import_userinfo.sh"
rm $ZDUMPDIR/gettingAccData.txt

#Parses import script for mailbox contents if archived
if [ $DoArchiveMBox ]
	then
#parsing mailbox import v2
		echo "=== Parsing script for importing contents of mailboxes of $DomainSelected  ==="
		mboxCount=`cat $ZDUMPDIR/gettingAccList.txt | wc -l`
		i=1
		for mboxImport in `cat $ZDUMPDIR/gettingAccList.txt`
			do
			echo "Processing $mboxImport ..."
#there are options:
#   "skip" ignores duplicates of old items, it’s also the default conflict-resolution.
#   "modify" changes old items.
#   "reset" will delete the old subfolder (or entire mailbox if /).
#   "replace" will delete and re-enter them.
#   use it wisely. Do not reset data on new server if you're not sure you want to.
			resolveOptions="replace"
			echo "printf 'Importing $mboxImport ($i of $mboxCount) ...\n'" >>  $ZDUMPDIR/$DomainSelected"_import_mailbox_contents.txt"
			echo $ZMBOX' -z -m '$mboxImport' postRestURL "//?fmt=tgz&resolve='$resolveOptions'" '$ZDUMPDIR'/'$mboxImport'.tgz' >> $ZDUMPDIR/$DomainSelected"_import_mailbox_contents.txt"
			((i++))
			done
		mv  $ZDUMPDIR/$DomainSelected"_import_mailbox_contents.txt"  $ZDUMPDIR/$DomainSelected"_import_mailbox_contents.sh"
fi
#cleaning up
rm $ZDUMPDIR/gettingAccList.txt

echo "=====================Your data have been SUCCESFULLY parsed at:==================="
echo $ZDUMPDIR"/"$DomainSelected"_import_userinfo.sh"
if [ $DoArchiveMBox ]; then echo $ZDUMPDIR"/"$DomainSelected"_import_mailbox_contents.sh"; echo "Mailboxes archived at "$ZDUMPDIR; fi
echo "===Files are not executable by default, if you want to run it, don't forget to:==="
echo "=================================================================================="
echo "chmod 755 "$ZDUMPDIR"/"$DomainSelected"_import_userinfo.sh"
if [ $DoArchiveMBox ]; then echo "chmod 755 "$ZDUMPDIR"/"$DomainSelected"_import_mailbox_contents.sh"; fi
echo "=================================================================================="
echo "Also, take care of locale before running "$ZDUMPDIR"/"$DomainSelected"_import_userinfo.sh"
echo "for example: export LC_ALL='ru_RU.UTF-8'"
echo "Spend time to check these files' contents before."
echo "Run them at new server by zimbra user. Good luck!"
