#!/bin/bash
if [ "$(id -u)" != "0" ]; then
	echo ""
	echo "'distromanager' must be run as root. Exiting . . ."
	echo ""
	exit 1
fi
##########################################################################################
## The opening code will run a series of checks to make sure all of the required components
## for running distribution points from the server are in place. The 'casperadmin' and
## 'casperinstall' accounts are also created.
##########################################################################################
## This first check will see if Netatalk is installed.  If not, it will be installed.  Then
## Netatalk will be configured so that Macs can connect to the created shares over AFP.
##########################################################################################
NETACHECK=$(dpkg-query -W -f='${Status}\n' netatalk)
if [ "${NETACHECK}" != "install ok installed" ]; then
	echo ""
	echo "Installing Netatalk (for AFP) . . ."
	apt-get install -y netatalk &> /dev/null
	/etc/init.d/netatalk stop
	if [ ! -e /etc/avahi/services/afpd.service ]; then
		echo ""
		echo "Creating the Netatalk AFP daemon . . ."
		sudo touch /etc/avahi/services/afpd.service
		echo "<?xml version=\"1.0\" standalone='no'?><!--*-nxml-*-->" >> /etc/avahi/services/afpd.service
		echo "<!DOCTYPE service-group SYSTEM \"avahi-service.dtd\">" >> /etc/avahi/services/afpd.service
		echo "<service-group>" >> /etc/avahi/services/afpd.service
		echo "     <name replace-wildcards=\"yes\">%h</name>" >> /etc/avahi/services/afpd.service
		echo "     <service>" >> /etc/avahi/services/afpd.service
		echo "          <type>_afpovertcp._tcp</type>" >> /etc/avahi/services/afpd.service
		echo "          <port>548</port>" >> /etc/avahi/services/afpd.service
		echo "     </service>" >> /etc/avahi/services/afpd.service
		echo "     <service>" >> /etc/avahi/services/afpd.service
		echo "          <type>_device-info._tcp</type>" >> /etc/avahi/services/afpd.service
		echo "          <port>0</port>" >> /etc/avahi/services/afpd.service
		echo "          <txt-record>model=Xserve</txt-record>" >> /etc/avahi/services/afpd.service
		echo "     </service>" >> /etc/avahi/services/afpd.service
		echo "</service-group>" >> /etc/avahi/services/afpd.service
	fi
	echo ""
	echo "Configuring Netatalk afpd.conf . . ."
	sed -i'' "s/# - -tcp -noddp -uamlist uams_dhx.so,uams_dhx2.so -nosavepassword/- -tcp -noddp -uamlist uams_dhx2.so -nosavepassword/g" /etc/netatalk/afpd.conf
	echo ""
	echo "Modifying AppleVolumes.default"
	sed -i'' "/# End of File/d" /etc/netatalk/AppleVolumes.default
	sed -i'' "/\/                      \"Home Directory\"/d" /etc/netatalk/AppleVolumes.default
	/etc/init.d/netatalk start
fi
##########################################################################################
## This will check if Samba is installed. If not, it is downloaded and configured.
##########################################################################################
SMBCHECK=$(dpkg-query -W -f='${Status}\n' samba)
if [ "${SMBCHECK}" != "install ok installed" ]; then
	echo ""
	echo "Installing Samba (for SMB) . . ."
	apt-get install -y samba &> /dev/null
	sed -i'' "s/#   security = user/   security = user/g" /etc/samba/smb.conf
	sed -i'' "s/#   encrypt passwords = true/   encrypt passwords = true/g" /etc/samba/smb.conf
	sed -i'' "s/[printers]/; [printers]/g" /etc/samba/smb.conf
	sed -i'' "s/   comment = All Printers/;   comment = All Printers/g" /etc/samba/smb.conf
	sed -i'' "s/   browseable = no/;   browseable = no/g" /etc/samba/smb.conf
	sed -i'' "s#   path = /var/spool/samba#;   path = /var/spool/samba#g" /etc/samba/smb.conf
	sed -i'' "s/   printable = yes/;   printable = yes/g" /etc/samba/smb.conf
	sed -i'' "s/   guest ok = no/;   guest ok = no/g" /etc/samba/smb.conf
	sed -i'' "s/   read only = yes/;   read only = yes/g" /etc/samba/smb.conf
	sed -i'' "s/   create mask = 0700/;   create mask = 0700/g" /etc/samba/smb.conf
	sed -i'' "s/   read only = yes# printer drivers/;   read only = yes# printer drivers/g" /etc/samba/smb.conf
	sed -i'' "s/[print$]/;[print$]/g" /etc/samba/smb.conf
	sed -i'' "s/   comment = Printer Drivers/;   comment = Printer Drivers/g" /etc/samba/smb.conf
	sed -i'' "s#   path = /var/lib/samba/printers#;   path = /var/lib/samba/printers#g" /etc/samba/smb.conf
	sed -i'' "s/   browseable = yes/;   browseable = yes/g" /etc/samba/smb.conf
	sed -i'' "s/   read only = yes/;   read only = yes/g" /etc/samba/smb.conf
	sed -i'' "s/   guest ok = no/;   guest ok = no/g" /etc/samba/smb.conf
fi
##########################################################################################
## If the /CasperShares/ directory does not exist, it is created.
##########################################################################################
if [ ! -d /srv/CasperShares/ ]; then
	echo ""
	echo "Creating the /CasperShares/ directory . . ."
	mkdir /srv/CasperShares
	chmod 755 /srv/CasperShares
fi
##########################################################################################
##
##########################################################################################
XMLCHECK=$(dpkg-query -W -f='${Status}\n' libxml2-utils)
if [ "${XMLCHECK}" != "install ok installed" ]; then
	echo ""
	echo "Installing libxml2-utils (for 'xmllint' command) . . ."
	apt-get install -y libxml2-utils &> /dev/null
fi
##########################################################################################
## Both the 'casperadmin' and 'casperinstall' users are checked for, and if not present
## they are created, added to the Samba user password list, and added to the 'sambashare'
## group which will have 'read and execute' priviliges to the shares.
##########################################################################################
CADCHECK=$(awk -F":" '/casperadmin/ { print $1 }' /etc/passwd)
if [ -z "${CADCHECK}" ]; then
	echo ""
	echo "Creating the user 'casperadmin' with password 'jamf1234' . . ."
	useradd casperadmin -d /home/casperadmin -p `openssl passwd -1 jamf1234`
	echo -en "jamf1234\njamf1234\n" | smbpasswd -as casperadmin
	useradd -G sambashare casperadmin
fi
CINCHECK=$(awk -F":" '/casperinstall/ { print $1 }' /etc/passwd)
if [ -z "${CINCHECK}" ]; then
	echo ""
	echo "Creating the user 'casperinstall' with password 'jamf1234' . . ."
	useradd casperinstall -d /home/casperinstall -p `openssl passwd -1 jamf1234`
	echo -en "jamf1234\njamf1234\n" | smbpasswd -as casperinstall
	useradd -G sambashare casperinstall
fi
##########################################################################################
## The Main Menu
##########################################################################################
function MAINMENU {
touch /tmp/sharelist.txt
ls /srv/CasperShares/ > /tmp/sharelist.txt
echo ""
echo "==============================================================================="
echo "| Your VM's Distribution Point Manager                                        |"
echo "|=============================================================================|"
echo "| Share Name              | Number of Files         | Estimated Size (in KB)  |"
echo "|=========================|=========================|=========================|"
while read CSPSHARE; do
	SHARENAME="| "$(printf "%-24s" "${CSPSHARE}")
	FILECOUNT=$(find /srv/CasperShares/"${CSPSHARE}"/ | wc -l)
	FILECOUNT="| "$(printf "%-24s" "${FILECOUNT}")
	SHARESIZE=$(du -sk /srv/CasperShares/"${CSPSHARE}" | cut -f 1)
	SHARESIZE="| "$(printf "%-24s" "${SHARESIZE}")"|"
	echo "${SHARENAME}${FILECOUNT}${SHARESIZE}"
	echo "|- - - - - - - - - - - - -|- - - - - - - - - - - - -|- - - - - - - - - - - - -|"
	VERSION=""
	FILECOUNT=""
done < /tmp/sharelist.txt
rm /tmp/sharelist.txt
read -sp "Press [ENTER] to continue . . . "
echo ""
echo ""
echo "==============================================================================="
echo "| Please select an option:                                                    |"
echo "==============================================================================="
showMenu () {
	echo "| 1) Create a new Casper Share                                                |"
	echo "| 2) Delete an existing Casper Share                                          |"
	echo "|  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  |"
	echo "| 3) Delete all Casper Shares and Users                                       |"
	echo "| 4) Uninstall AFP and SMB services                                           |"
	echo "|  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  |"
	echo "| 5) Populate dummy items into a Casper Share                                 |"
	echo "|  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  |"
	echo "| X) Exit the Casper Share Manager                                            |"
	echo "-------------------------------------------------------------------------------"
	echo ""
}
while [ 1 ]
do
	showMenu
	read -p "Your selection: " CHOICE
	case "$CHOICE" in
		"1") createCasperShare; break;;
		"2") deleteCasperShare; break;;
		"3") deleteALL; break;;
		"4") uninstallALL; break;;
		"5") dummyPackages; break;;
		"x" | "X") EXITSCRIPT; break;;
	esac
done
MAINMENU
}
##########################################################################################
##
##########################################################################################
function createCasperShare {
echo ""
echo "Please enter the name of the Casper Share you are creating."
echo "It is recommended to not use spaces or special characters."
read -p "Casper Share name: " NEWSHARE
if [ -d /srv/CasperShares/"${NEWSHARE}"/ ]; then
	echo ""
	echo "The Casper Share already exists. Returning to Main Menu . . ."
	break
fi
echo ""
echo "Creating the new Casper Share directory . . ."
mkdir /srv/CasperShares/"${NEWSHARE}"/
chmod 755 /srv/CasperShares/"${NEWSHARE}"/
chown casperadmin:sambashare /srv/CasperShares/"${NEWSHARE}"/
mkdir /srv/CasperShares/"${NEWSHARE}"/Casper\ Data/
chmod 755 /srv/CasperShares/"${NEWSHARE}"/Casper\ Data/
chown casperadmin:sambashare /srv/CasperShares/"${NEWSHARE}"/Casper\ Data/
mkdir /srv/CasperShares/"${NEWSHARE}"/CompiledConfigurations/
chmod 755 /srv/CasperShares/"${NEWSHARE}"/CompiledConfigurations/
chown casperadmin:sambashare /srv/CasperShares/"${NEWSHARE}"/CompiledConfigurations/
mkdir /srv/CasperShares/"${NEWSHARE}"/Packages/
chmod 755 /srv/CasperShares/"${NEWSHARE}"/Packages/
chown casperadmin:sambashare /srv/CasperShares/"${NEWSHARE}"/Packages/
mkdir /srv/CasperShares/"${NEWSHARE}"/Scripts/
chmod 755 /srv/CasperShares/"${NEWSHARE}"/Scripts/
chown casperadmin:sambashare /srv/CasperShares/"${NEWSHARE}"/Scripts/
echo ""
echo "Configuring Samba (SMB) . . ."
echo "## ${NEWSHARE} START" >> /etc/samba/smb.conf
echo "[${NEWSHARE}]" >> /etc/samba/smb.conf
echo "comment = ${NEWSHARE}" >> /etc/samba/smb.conf
echo "path = /srv/CasperShares/${NEWSHARE}"/ >> /etc/samba/smb.conf
echo "browsable = yes" >> /etc/samba/smb.conf
echo "guest ok = no" >> /etc/samba/smb.conf
echo "read only = no" >> /etc/samba/smb.conf
echo "create mask = 0755" >> /etc/samba/smb.conf
echo "## ${NEWSHARE} END" >> /etc/samba/smb.conf
echo ""
sudo restart smbd
sudo restart nmbd
echo ""
echo "Configuring Netatalk (AFP) . . ."
echo "/srv/CasperShares/${NEWSHARE} \"${NEWSHARE}\" cnidscheme:dbd" >> /etc/netatalk/AppleVolumes.default
/etc/init.d/netatalk restart
}
##########################################################################################
##
##########################################################################################
function deleteCasperShare {
checkAvailable
rm /tmp/sharelist.txt
shareChoose
echo ""
echo "WARNING: You cannot undo this action. Do you still wish to proceed?"
read -p "Yes/No: " CHOICE
case "$CHOICE" in
		"y" | "Y" | "YES" | "Yes" | "yes") ;;
		"n" | "N" | "NO" | "No" | "no") echo "User has cancelled deletion."; break;;
esac
echo ""
echo "Removing /${CSPSHARE}/ directory and contents . . ."
rm -rf /srv/CasperShares/"${CSPSHARE}"/
echo ""
echo "Removing Samba (SMB) configuration . . ."
sed -i'' "/## ${CSPSHARE} START/,/## ${CSPSHARE} END/{//!d}" /etc/samba/smb.conf
sed -i'' "/## ${CSPSHARE} START/d" /etc/samba/smb.conf
sed -i'' "/## ${CSPSHARE} END/d" /etc/samba/smb.conf
echo ""
sudo restart smbd
sudo restart nmbd
echo ""
echo "Removing Netatalk (AFP) configuration . . ."
sed -i'' "/\/srv\/CasperShares\/${CSPSHARE} \"${CSPSHARE}\" cnidscheme:dbd/d" /etc/netatalk/AppleVolumes.default
/etc/init.d/netatalk restart
echo ""
}
##########################################################################################
function dummyPackages {
echo ""
echo "==============================================================================="
echo "| The dummy packages feature allows you to populate a selected Casper Share   |"
echo "| with empty files that will mimic packages, DMGs and other file.             |"
echo "|  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  |"
echo "| For example, you may read the package list from another JSS to populate     |"
echo "| your demo Casper Share, or if you have imported a MySQL database into one   |"
echo "| of your contexts, you may read against that JSS to create the dummy         |"
echo "| packages to match what is in the database's records.                        |"
echo "==============================================================================="
read -sp "Press [ENTER] to continue . . . "
echo ""
checkAvailable
shareChoose
jssInformation
readJSSxml
rm /tmp/packages.xml
rm /tmp/packages.list
}
##########################################################################################
function jssInformation {
echo ""
echo "Enter the full URL of the JSS you wish to read package data from."
echo "Example: 'https://your.jss.com/' or 'https://jssgrabber.local:8080/'"
read -p "JSS URL: " JSSaddress
echo ""
echo "Enter the name of a user account with API read access to the JSS."
read -p "User account: " JSSUSER
echo ""
echo "Enter the password to the user account."
read -sp "Password: " JSSPASS
echo ""
URLCHK=$(curl -u "${JSSUSER}":"${JSSPASS}" -o /dev/null --silent --head --write-out '%{http_code}\n' "${JSSaddress}JSSResource/packages")
if [ "${URLCHK}" = "401" ]; then
	echo ""
	echo "The account and password entered are incorrect or the account does not have."
	echo "API read access to the target JSS. Please try again."
	jssInformation
elif [ "${URLCHK}" != "200" ]; then
	echo ""
	echo "You have entered an invalid JSS address. If you are targeting a JSS context,"
	echo "include it with your URL path. Please try again."
	jssInformation
fi
}
##########################################################################################
function readJSSxml {
echo ""
echo "Reading the available packages from the target JSS . . ."
curl -u "${JSSUSER}":"${JSSPASS}" -k --silent "${JSSaddress}"JSSResource/packages -X GET | xmllint --format - > /tmp/packages.xml
echo "Creating package list . . ."
awk -F"<name>|</name>" '{ print $2 }' /tmp/packages.xml | tr -s '\n' > /tmp/packages.list
if [ ! -d /srv/CasperShares/"${CSPSHARE}"/Packages/ ]; then
	mkdir /srv/CasperShares/"${CSPSHARE}"/Packages/
	chmod 755 /srv/CasperShares/"${CSPSHARE}"/Packages/
	chown casperadmin:sambashare /srv/CasperShares/"${CSPSHARE}"/Packages/
fi
while read FILENAME; do
	touch /srv/CasperShares/"${CSPSHARE}"/Packages/"${FILENAME}"
	chmod 755 /srv/CasperShares/"${CSPSHARE}"/Packages/"${FILENAME}"
	chown casperadmin:sambashare /srv/CasperShares/"${CSPSHARE}"/Packages/"${FILENAME}"
done < /tmp/packages.list
echo "Reading the available scripts from the target JSS . . ."
curl -u "${JSSUSER}":"${JSSPASS}" -k --silent "${JSSaddress}"JSSResource/scripts -X GET | xmllint --format - > /tmp/scripts.xml
echo "Creating script list . . ."
awk -F"<name>|</name>" '{ print $2 }' /tmp/scripts.xml | tr -s '\n' > /tmp/scripts.list
if [ ! -d /srv/CasperShares/"${CSPSHARE}"/Scripts/ ]; then
	mkdir /srv/CasperShares/"${CSPSHARE}"/Scripts/
	chmod 755 /srv/CasperShares/"${CSPSHARE}"/Scripts/
	chown casperadmin:sambashare /srv/CasperShares/"${CSPSHARE}"/Scripts/
fi
while read FILENAME; do
	touch /srv/CasperShares/"${CSPSHARE}"/Scripts/"${FILENAME}"
	chmod 755 /srv/CasperShares/"${CSPSHARE}"/Scripts/"${FILENAME}"
	chown casperadmin:sambashare /srv/CasperShares/"${CSPSHARE}"/Scripts/"${FILENAME}"
done < /tmp/scripts.list
echo ""
echo "The dummy items have been written to the ${CSPSHARE} share."
}
##########################################################################################
function shareChoose {
echo ""
echo "Please enter the name of the selected Casper Share."
read -p "Casper Share name: " CSPSHARE
if [ ! -d /srv/CasperShares/"${CSPSHARE}"/ ]; then
	echo ""
	echo "You have entered an invalid share name. Please try again."
	shareChoose
fi
}
##########################################################################################
function checkAvailable {
ls /srv/CasperShares/ > /tmp/sharelist.txt
if [ ! -s /tmp/sharelist.txt ]; then
	echo ""
	echo "There are no available Casper Shares. Returning to Main Menu . . ."
	rm /tmp/sharelist.txt
	break
fi
}
##########################################################################################
##
##########################################################################################
function deleteALL {
echo ""
echo "Deleting all Casper Shares and Users . . ."
echo "WARNING: You cannot undo this action. Do you still wish to proceed?"
read -p "Yes/No: " CHOICE
case "$CHOICE" in
		"y" | "Y" | "YES" | "Yes" | "yes") ;;
		"n" | "N" | "NO" | "No" | "no") echo "User has cancelled deletion."; break;;
esac
echo ""
echo "Removing /CasperShares/ directory and contents . . ."
touch /tmp/sharelist.txt
ls /srv/CasperShares/ > /tmp/sharelist.txt
if [ -s /tmp/sharelist.txt ]; then
	while read CSPSHARE; do
		sed -i'' "/## ${CSPSHARE} START/,/## ${CSPSHARE} END/{//!d}" /etc/samba/smb.conf
		sed -i'' "/## ${CSPSHARE} START/d" /etc/samba/smb.conf
		sed -i'' "/## ${CSPSHARE} END/d" /etc/samba/smb.conf
		sed -i'' "/\/srv\/CasperShares\/${CSPSHARE} \"${CSPSHARE}\" cnidscheme:dbd/d" /etc/netatalk/AppleVolumes.default
	done < /tmp/sharelist.txt
fi
rm -rf /srv/CasperShares/
rm /tmp/sharelist.txt
echo ""
echo "Removing 'casperadmin' and 'casperinstall' account . . ."
smbpasswd -sx casperadmin
smbpasswd -sx casperinstall
deluser --quiet casperadmin
deluser --quiet casperinstall
echo ""
sudo restart smbd
sudo restart nmbd
/etc/init.d/netatalk restart
echo ""
echo "All Casper Shares and users have been deleted. The directories and user accounts"
echo "will be recreated when you relaunch the Distribution Point Manager."
read -sp "Press [ENTER] to exit . . . "
echo ""
EXITSCRIPT
}
##########################################################################################
##
##########################################################################################
function uninstallALL {
echo ""
echo "Only run this uninstall option if you are experiencing problems with mounting your"
echo "Casper Shares after making changes to their configurations."
echo ""
echo "Uninstalling the ACL, AFP and SMB services . . ."
echo "WARNING: You cannot undo this action. Do you still wish to proceed?"
read -p "Yes/No: " CHOICE
case "$CHOICE" in
		"y" | "Y" | "YES" | "Yes" | "yes") ;;
		"n" | "N" | "NO" | "No" | "no") echo "User has cancelled deletion."; break;;
esac
apt-get purge -qqy samba netatalk
echo ""
echo "Samba (SMB) and Netatalk (AFP) have been removed from the server. They will be"
echo "reinstalled and reconfigured when you relaunch the Distribution Point Manager."
read -sp "Press [ENTER] to exit . . . "
echo ""
EXITSCRIPT
}
##########################################################################################
##
##########################################################################################
function EXITSCRIPT {
echo ""
exit 0
}
##########################################################################################
echo ""
echo "==============================================================================="
echo "| The Distribution Point Manager allows you to create Casper Shares for your  |"
echo "| JSS contexts. These can be shared between different JSS contexts, or you    |"
echo "| may create unique Casper Shares for each context. All of the Casper Shares  |"
echo "| will share the same \"casperadmin\" and \"casperinstall\" accounts for access.    |"
echo "| The default password for both accounts is \"jamf1234\".                       |"
echo "|-----------------------------------------------------------------------------|"
echo "| NOTE: If you are testing or demoing a 9.x instance of the JSS, it is highly |"
echo "| recommended that you use a JDS virtual machine enrolled to that instance    |"
echo "| for your distribution point.                                                |"
echo "==============================================================================="
MAINMENU
##########################################################################################
exit 0