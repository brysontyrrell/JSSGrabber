#!/bin/bash
# JSSGrabber v7.0

# Check if the JSSGrabber log exists and starts the logging entries.
if [ ! -e /srv/jssgrabber/logs/jssgrabber.log ]; then
	if [ ! -e /srv/jssgrabber/logs/ ]; then
		mkdir -p /srv/jssgrabber/logs/
	fi
	touch /srv/jssgrabber/logs/jssgrabber.log
	chmod 744 /srv/jssgrabber/logs/jssgrabber.log
	echo "JSSGrabber log file was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi
echo "." >> /srv/jssgrabber/logs/jssgrabber.log
echo ".." >> /srv/jssgrabber/logs/jssgrabber.log
echo "Starting new log entries for:" >> /srv/jssgrabber/logs/jssgrabber.log
date >> /srv/jssgrabber/logs/jssgrabber.log

#*****************************************************************************************

# This checks to see if the program is being run as root which is required.
if [ "$(id -u)" != "0" ]; then
	echo ""
	echo "The JSSGrabber must be run as root. Exiting..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	exit 1
fi

echo ""
echo "Loading the JSSGrabber..." | tee -a /srv/jssgrabber/logs/jssgrabber.log

#*****************************************************************************************
# The JSSGrabber will now check that the required application support directories are in
# place.  If any are missing they will be recreated.

echo ""
echo "Running file and directory checks..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo ""

if [ ! -d /srv/jssgrabber/ ]; then
	mkdir  /srv/jssgrabber/
	echo "JSSGrabber directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/configbackups/ ]; then
	mkdir /srv/jssgrabber/configbackups/
	echo "Configuration Backup directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/dbimports/ ]; then
	mkdir /srv/jssgrabber/dbimports/
	echo "Database Import directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/jsswars/ ]; then
	mkdir /srv/jssgrabber/jsswars/
	echo "JSS WAR File directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/keystores/ ]; then
	mkdir /srv/jssgrabber/keystores/
	echo "Keystore directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/settings/ ]; then
	mkdir /srv/jssgrabber/settings/
	echo "JSSGrabber Settings directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

if [ ! -d /srv/jssgrabber/shares/ ]; then
	mkdir /srv/jssgrabber/shares/
	echo "Distribution Point Shares directory was missing. Recreated." >> /srv/jssgrabber/logs/jssgrabber.log
fi

#*****************************************************************************************
# Each time the JSSGrabber opens it will perform a series of checks to ensure that all of
# the required services are installed on the virtual machine. If not, they are installed
# and configured correctly.

echo "Updating the server package list..." >> /srv/jssgrabber/logs/jssgrabber.log
apt-get update &> /dev/null

echo "Running services checks..." | tee -a /srv/jssgrabber/logs/jssgrabber.log

packageCheck=$(dpkg-query -W -f='${Status}\n' avahi-daemon)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing the Avahi Daemon (Bonjour)..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y avahi-daemon &> /dev/null
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' openjdk-7-jdk)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing OpenJDK 1.7 JDK..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y openjdk-7-jdk &> /dev/null
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' mysql-server-5.5)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing MySQL Server 5.5..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y mysql-server-5.5 &> /dev/null
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' tomcat7)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing Apache Tomcat..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	apt-get install -y tomcat7 &> /dev/null
	echo "Creating backup of 'server.xml' to '/srv/jssgrabber/configbackups/sever.xml.backup'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	cp /var/lib/tomcat7/conf/server.xml /srv/jssgrabber/configbackups/server.xml.backup
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' unzip)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing Unzip..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y unzip &> /dev/null
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' sshpass)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing sshpass..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y sshpass &> /dev/null
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' netatalk)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing Netatalk (for AFP)..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	apt-get install -y netatalk &> /dev/null
	/etc/init.d/netatalk stop | tee -a /srv/jssgrabber/logs/jssgrabber.log
	if [ ! -e /etc/avahi/services/afpd.service ]; then
		echo "Creating the Netatalk AFP daemon..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
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

	echo "Creating backup of 'afpd.service' to '/srv/jssgrabber/configbackups/afpd.service.backup'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	cp /etc/avahi/services/afpd.service /srv/jssgrabber/configbackups/afpd.service.backup

	echo "Configuring Netatalk 'afpd.conf'..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	sed -i'' "s/# - -tcp -noddp -uamlist uams_dhx.so,uams_dhx2.so -nosavepassword/- -tcp -noddp -uamlist uams_dhx2.so -nosavepassword/g" /etc/netatalk/afpd.conf

	echo "Creating backup of 'afpd.conf' to '/srv/jssgrabber/configbackups/afpd.conf.backup'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	cp /etc/netatalk/afpd.conf /srv/jssgrabber/configbackups/afpd.conf.backup

	echo "Modifying 'AppleVolumes.default'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	sed -i'' "/# End of File/d" /etc/netatalk/AppleVolumes.default
	sed -i'' "/\/                      \"Home Directory\"/d" /etc/netatalk/AppleVolumes.default

	echo "Creating backup of 'AppleVolumes.default' to '/srv/jssgrabber/configbackups/AppleVolumes.default.backup'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	cp /etc/netatalk/AppleVolumes.default /srv/jssgrabber/configbackups/AppleVolumes.default.backup

	echo ""	
	/etc/init.d/netatalk start | tee -a /srv/jssgrabber/logs/jssgrabber.log
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' samba)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing Samba (for SMB)..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	apt-get install -y samba &> /dev/null
	
	echo "Configuring Samba 'smb.conf'..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
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

	echo "Creating backup of 'smb.conf' to '/srv/jssgrabber/configbackups/smb.conf.backup'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	cp /etc/samba/smb.conf /srv/jssgrabber/configbackups/smb.conf.backup
fi

packageCheck=$(dpkg-query -W -f='${Status}\n' libxml2-utils)
if [ "${packageCheck}" != "install ok installed" ]; then
	echo "Installing libxml2-utils (for 'xmllint' command)..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo ""
	apt-get install -y libxml2-utils &> /dev/null
fi

#*****************************************************************************************
#*****************************************************************************************

function mainMenu {
# Clear out all global variables upon return to the main menu.
errorCheck="" # Variable used for canceling functions and returning to the Main Menu
errorLoop=0 # This variable is used for triggering the errorCheck
noJSS="" # The noJSS variable will prevent the user from executing some options for configuring MySQL databases if they have not deployed a JSS context
jssVersion="" # Will trigger different commands depending upon the version of the deploted JSS context
jssDatabaseXML="" # Sets the name of the Database/DataBase.xml file depending on the version of the deployed JSS context
REMOTEDB=""

# Tomcat status check is run every time the Main Menu is loaded. If the service status
# does not return a "0" for 'running' then the service is restarted.
service tomcat7 status &> /dev/null
if [ $? -ne 0 ]; then
	echo ""
	service tomcat7 restart | tee -a /srv/jssgrabber/logs/jssgrabber.log
	if [ $? -ne 0 ]; then
		echo ""
		echo "================================================================================"
		echo "| Tomcat failed to start. There may be a problem with the 'server.xml' file.   |" | tee -a /srv/jssgrabber/logs/jssgrabber.log
		echo "| You may try restoring the file from  'JSSGrabber Server Configuration'.      |"
		echo "================================================================================"
	fi
fi

clear
echo "" | tee -a /srv/jssgrabber/logs/jssgrabber.log
showMenu () {
	echo "================================================================================"
	echo "| JSSGrabber v7.0: Main Menu                                                   |" | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "|------------------------------------------------------------------------------|"
	echo "| Please select an option:                                                     |"
	echo "|==============================================================================|"
	echo "| 1) Deploy a JSS context                                                      |"
	echo "| 2) Create or Configure a MySQL Database                                      |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 3) Open the JSS Manager                                                      |"
	echo "| 4) Open the Distribution Point Manager                                       |"
	echo "| 5) Open the Certificate Manager                                              |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 6) Read the Virtual Machine's Manual                                         |"
	echo "| 7) View the programs' source code                                            |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| C) JSSGrabber Server Configuration                                           |"
	echo "| U) Update the JSSGrabber                                                     |"
	echo "| R) Restart Tomcat Now                                                        |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| X) Exit to Ubuntu Command Line                                               |"
	echo "| S) Shutdown or Reboot the JSSGrabber Server                                  |"
	echo "|==============================================================================="
}

while [ 1 ]
do
	showMenu
	read -p "| Your selection: " CHOICE
	case "$CHOICE" in
		"1") deployJSS; break;;
		"2") noJSS="true"; mysqlMenu; break;;
		"3") jssManager; break;;
		"4") distroManager; break;;
		"5") certManager; break;;
		"6") manPage; break;;
		"7") viewSource; break;;
		"c"|"C") configMenu; break;;
		"u"|"U") jamfUpdate; break;;
		"r"|"R") restartTomcat; break;;
		"x"|"X") exitProgram; break;;
		"s"|"S" ) serverShutdown; break;;
	esac
done
}

#*****************************************************************************************
#*****************************************************************************************

function deployJSS {
echo "Deploy a JSS context" >> /srv/jssgrabber/logs/jssgrabber.log

echo "|"
echo "|==============================================================================="
read -p "| Please enter the name of your new JSS context (leave blank for ROOT): " jssContextName
if [ -z "${jssContextName}" ]; then
	jssContextName="ROOT"
fi

deployJSS_select

service tomcat7 stop | tee -a /srv/jssgrabber/logs/jssgrabber.log

if [ -d /var/lib/tomcat7/webapps/"${jssContextName}"/ ]; then
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
	echo "| There is an existing context of the selected name." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "| Removing the JSS context and all supporting files." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	rm -rf /var/lib/tomcat7/webapps/"${jssContextName}"
	if [ -d /var/lib/tomcat7/work/Catalina/localhost/"${jssContextName}"/ ]; then
		rm -rf /var/lib/tomcat7/work/Catalina/localhost/"${jssContextName}"
	fi
	if [ -d /var/log/"${jssContextName}"/ ]; then
		rm -rf /var/log/"${jssContextName}"
	fi
	if [ -d /srv/jssgrabber/configbackups/"${jssContextName}"/ ]; then
		rm -rf /srv/jssgrabber/configbackups/"${jssContextName}"/
	fi
fi

if [ ! -d /srv/jssgrabber/configbackups/"${jssContextName}"/ ]; then
	mkdir -p /srv/jssgrabber/configbackups/"${jssContextName}"/
fi

echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| Deploying the JSS ${jssRelease} WAR file..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
mkdir /var/lib/tomcat7/webapps/"${jssContextName}"/
cp /srv/jssgrabber/jsswars/"${jssRelease}".war /var/lib/tomcat7/webapps/"${jssContextName}"/ROOT.war
cd /var/lib/tomcat7/webapps/"${jssContextName}"/
jar xf ROOT.war
rm /var/lib/tomcat7/webapps/"${jssContextName}"/ROOT.war
cd ~/

deployJSS_logFiles

echo "|-------------------------------------------------------------------------------"
echo "| The JSS WAR file has been deployed." | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| Tomcat will restart after you have selected your database options."
echo "================================================================================"
read -sp "| Press [ENTER] to continue..."
echo ""

if [ ${jssVersion} = 8 ]; then
	jssDatabaseXML="DataBase.xml"
else
	jssDatabaseXML="Database.xml"
fi

mysqlMenu

chown -R tomcat7:tomcat7 /var/lib/tomcat7/webapps/"${jssContextName}"

echo "|-------------------------------------------------------------------------------"
read -sp "| Press [ENTER] to return to the Main Menu... "
echo ""

}

#*****************************************************************************************

function deployJSS_select {
if [ $errorLoop -eq 3 ]; then
	echo "|-------------------------------------------------------------------------------"
	echo "| You have made three invalid inputs.  You will be returned to the Main Menu..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "|-------------------------------------------------------------------------------"
	read -sp "| Press [ENTER] to continue..."
	echo ""
	break
fi

echo "================================================================================"
echo "| Available JSS releases:"
echo "|-------------------------------------------------------------------------------"
echo "|    8.3     |    8.31    |    8.4     |    8.41    |    8.43    |    8.5"
echo "| -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  -  -"
echo "|    8.51    |    8.52    |    8.6     |    8.62    |    8.63    |    8.64"
echo "| -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  - | -  -  -  -  -"
echo "|    8.7     |            |            |            |            |"
echo "|-------------------------------------------------------------------------------"
read -p "| Enter your selection: " jssRelease

if [ ! -e /srv/jssgrabber/jsswars/"${jssRelease}".war ]; then
	URLCHK=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' {REDACTED}/"${jssRelease}".war)
	if [ ${URLCHK} -ne 200 ]; then
			echo "|-------------------------------------------------------------------------------"
			echo "| You specified an invalid JSS version, or there is no available WAR file." | tee -a /srv/jssgrabber/logs/jssgrabber.log
			echo "| Please try again." | tee -a /srv/jssgrabber/logs/jssgrabber.log
			errorLoop=$((errorLoop+1))
			deployJSS_select
	fi
	deployJSS_select_download
fi

if [ "${jssRelease:0:1}" = "8" ]; then
	jssVersion="8"
else
	jssVersion="9"
fi
}

#*****************************************************************************************

function deployJSS_select_download {
WARSIZE=$(curl -Iks {REDACTED}/"${jssRelease}".war | tr -d '\r' | awk '/Content-Length/ {print $2}')
echo "|-------------------------------------------------------------------------------"
echo "| Downloading the JSS ${jssRelease} WAR file." | tee -a /srv/jssgrabber/logs/jssgrabber.log

curl -fkS --progress-bar {REDACTED}/"${jssRelease}".war -o /srv/jssgrabber/jsswars/"${jssRelease}".war
CKWARSIZE=$(cksum /srv/jssgrabber/jsswars/"${jssRelease}".war | awk '{print $2}')
echo "|-------------------------------------------------------------------------------"
echo "| Verifying the downloaded WAR file..."

if [[ CKWARSIZE -ne WARSIZE ]]; then
	rm /srv/jssgrabber/jsswars/"${jssRelease}".war
	echo "| The WAR file failed to download properly. Exiting..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "|-------------------------------------------------------------------------------"
	read -sp "| Press [ENTER] to continue... "
	break
else
	echo "| The WAR file successfully downloaded." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "|-------------------------------------------------------------------------------"
fi

}

#*****************************************************************************************

function deployJSS_logFiles {
echo "| Creating log files for ${jssContextName} in '/var/log/${jssContextName}/'." | tee -a /srv/jssgrabber/logs/jssgrabber.log
mkdir -p /var/log/"${jssContextName}"/

touch /var/log/"${jssContextName}"/JAMFSoftwareServer.log 
touch /var/log/"${jssContextName}"/JAMFChangeManagement.log 
chown -R tomcat7:tomcat7 /var/log/"${jssContextName}"/

echo "| Backing up the log4j file(s) to '/srv/jssgrabber/configbackups/${jssContextName}/'" | tee -a /srv/jssgrabber/logs/jssgrabber.log

if [ "${jssVersion}" = "8" ]; then
	cp /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties /srv/jssgrabber/configbackups/"${jssContextName}"/log4j.properties.backup
	cp /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.JAMFCMFILE.properties /srv/jssgrabber/configbackups/"${jssContextName}"/log4j.JAMFCMFILE.properties.backup
	cp /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties /srv/jssgrabber/configbackups/"${jssContextName}"/log4j.JAMFCMSYSLOG.properties.backup
	sed -i'' -e "s#log4j.appender.JAMFCMFILE.File=/Library/JSS/Logs/jamfChangeManagement.log#log4j.appender.JAMFCMFILE.File=/var/log/${jssContextName}/jamfChangeManagement.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties
	sed -i'' -e "s#log4j.appender.JAMF.File=/Library/JSS/Logs/JAMFSoftwareServer.log#log4j.appender.JAMF.File=/var/log/${jssContextName}/JAMFSoftwareServer.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties
	sed -i'' -e "s#log4j.appender.JAMFCMFILE.File=/Library/JSS/Logs/jamfChangeManagement.log#log4j.appender.JAMFCMFILE.File=/var/log/${jssContextName}/jamfChangeManagement.log#" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.JAMFCMFILE.properties
	sed -i'' -e "s#log4j.appender.JAMF.File=/Library/JSS/Logs/JAMFSoftwareServer.log#log4j.appender.JAMF.File=/var/log/${jssContextName}/JAMFSoftwareServer.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.JAMFCMFILE.properties
	sed -i'' -e "s#log4j.appender.JAMF.File=/Library/JSS/Logs/JAMFSoftwareServer.log#log4j.appender.JAMF.File=/var/log/${jssContextName}/JAMFSoftwareServer.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties
fi

if [ "${jssVersion}" = "9" ]; then
	cp /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties /srv/jssgrabber/configbackups/"${jssContextName}"/log4j.properties.backup
	sed -i'' -e "s#log4j.appender.JAMF.File=/Library/JSS/Logs/JAMFSoftwareServer.log#log4j.appender.JAMF.File=/var/log/${jssContextName}/JAMFSoftwareServer.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties
	sed -i'' -e "s#log4j.appender.JAMFCMFILE.File=/Library/JSS/Logs/JAMFChangeManagement.log#log4j.appender.JAMFCMFILE.File=/var/log/${jssContextName}/jamfChangeManagement.log#g" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/classes/log4j.properties
fi
}

#*****************************************************************************************
#*****************************************************************************************

function mysqlMenu {
echo "Create or Configure a MySQL Database" >> /srv/jssgrabber/logs/jssgrabber.log

echo ""
showMenu () {
	echo "================================================================================"
	echo "| MySQL Database Creation and Configuration Menu:                              |"
	echo "|==============================================================================|"
	echo "| 1) Download and restore the Demo database                                    |"
	echo "| 2) Download and restore the EDU database                                     |"
	echo "| 3) Import and restore a JSS database (in beta)                               |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 4) Duplicate an existing JSS database                                        |"
	echo "| 5) Create a new JSS database                                                 |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 6) Connect to an existing local JSS database                                 |"
	echo "| 7) Connect to an existing remote JSS database                                |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| X) Return to Main Menu                                                       |"
	echo "|==============================================================================="
}
while [ 1 ]
do
	showMenu
	read -p "| Your selection: " CHOICE
	case "$CHOICE" in
		"1") mysqlMenu_demo; break;;
		"2") mysqlMenu_edu; break;;
		"3") mysqlMenu_import; break;;
		"4") mysqlMenu_duplicate; break;;
		"5") mysqlMenu_new; break;;
		"6") mysqlMenu_connect_local; break;;
		"7") mysqlMenu_connect_remote; break;;
		"x"|"X") break;;
	esac
done

echo "|"
echo "| Running cleanup..."
sudo rm -rf /tmp/grabberfiles/*.sql 2> /dev/null
}

#*****************************************************************************************
#*****************************************************************************************

function mysqlMenu_mysqlAuthenticate {
if [ $errorLoop -eq 3 ]; then
	echo "|-------------------------------------------------------------------------------"
	echo "| You have made three invalid inputs.  You will be returned to the Main Menu..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	echo "|-------------------------------------------------------------------------------"
	read -sp "| Press [ENTER] to continue..."
	echo ""
	break
fi

MYSQL="/usr/bin/mysql -uroot"
MYSQLDUMP="/usr/bin/mysqldump -uroot"
read -sp "| Please enter the root password for MySQL (leave blank if there is none): " MYSQLRPASS
echo ""

if [ ! -z "$MYSQLRPASS" ]; then
     MYSQL="${MYSQL} -p${MYSQLRPASS}"
     MYSQLDUMP="${MYSQLDUMP} -p${MYSQLRPASS}"
fi

$MYSQL -e ";" 2> /dev/null

if [ $? -gt 0 ]; then
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
	echo "| Incorrect root password entered. Please try again." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	errorLoop=$((errorLoop+1))
	mysqlMenu_mysqlAuthenticate
fi

echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| MySQL authentication successful." | tee -a /srv/jssgrabber/logs/jssgrabber.log
}

#*****************************************************************************************

function mysqlMenu_demo {
DBSIZE=$(curl -sI {REDACTED}/demo86.sql.gz | tr -d '\r' | awk '/Content-Length/ {print $2}')
echo "|-------------------------------------------------------------------------------"
echo "| Downloading the demo JSS database." | tee -a /srv/jssgrabber/logs/jssgrabber.log
curl -fkS --progress-bar {REDACTED}/demo86.sql.gz -o /demo86.sql.gz
CKDBSIZE=$(cksum /demo86.sql.gz | awk '{print $2}')
echo "| Verifying the downloaded demo JSS database file..."
if [[ CKDBSIZE -ne DBSIZE ]]; then
		rm /demo86.sql.gz
		echo "| The demo JSS database failed to download properly. Exiting..." | tee -a srv/jssgrabber/logs/jssgrabber.log
		echo "|-------------------------------------------------------------------------------"
		echo ""
		break
	else
		echo "| The demo JSS database successfully downloaded." | tee -a /srv/jssgrabber/logs/jssgrabber.log
		echo "|-------------------------------------------------------------------------------"
fi

mysqlMenu_mysqlAuthenticate

echo "|-------------------------------------------------------------------------------"
echo "| Decompressing Gzip'd SQL file." | tee -a /srv/jssgrabber/logs/jssgrabber.log

if [ ! -d /tmp/grabberfiles/ ]; then
	mkdir /tmp/grabberfiles/
fi

mv -f /demo86.sql.gz /tmp/grabberfiles/demo86.sql.gz
gzip -df /tmp/grabberfiles/demo86.sql.gz 2> /srv/jssgrabber/logs/jssgrabber.log

if [ $? -ne 0 ]; then
	echo "| There was an error extracting the file." | tee -a /srv/jssgrabber/logs/jssgrabber.log
fi

mysqlMenu_getDatabaseInfo

echo "|-------------------------------------------------------------------------------"
echo "| Restoring the database to '${DBNAME}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| This may take several minutes..."
$MYSQL -e "drop database if exists ${DBNAME}"
$MYSQL -e "create database ${DBNAME}"
$MYSQL ${DBNAME} < /tmp/grabberfiles/demo86.sql
$MYSQL -e "grant all on ${DBNAME}.* to '${DBUSER}'@localhost identified by '${DBPASS}'"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The demo database has been restored to '${DBNAME}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| Permissions have been granted for the user '${DBUSER}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| with the password '${DBPASS}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log

mysqlMenu_writeDatabaseXML

echo "|-------------------------------------------------------------------------------"
}

#*****************************************************************************************

function mysqlMenu_edu {
DBSIZE=$(curl -sI {REDACTED}/edu86.sql.gz | tr -d '\r' | awk '/Content-Length/ {print $2}')
echo "|-------------------------------------------------------------------------------"
echo "| Downloading the JAMF EDU JSS database." | tee -a /srv/jssgrabber/logs/jssgrabber.log
curl -fkS --progress-bar {REDACTED}/edu86.sql.gz -o /edu86.sql.gz
CKDBSIZE=$(cksum /edu86.sql.gz | awk '{print $2}')
echo "| Verifying the downloaded demo JSS database file..."
if [[ CKDBSIZE -ne DBSIZE ]]; then
		rm /edu86.sql.gz
		echo "| The EDU JSS database failed to download properly. Exiting..." | tee -a srv/jssgrabber/logs/jssgrabber.log
		echo "|-------------------------------------------------------------------------------"
		echo ""
		break
	else
		echo "| The EDU JSS database successfully downloaded." | tee -a /srv/jssgrabber/logs/jssgrabber.log
		echo "|-------------------------------------------------------------------------------"
fi

mysqlMenu_mysqlAuthenticate

echo "|-------------------------------------------------------------------------------"
echo "| Decompressing Gzip'd SQL file." | tee -a /srv/jssgrabber/logs/jssgrabber.log

if [ ! -d /tmp/grabberfiles/ ]; then
	mkdir /tmp/grabberfiles/
fi

mv -f /edu86.sql.gz /tmp/grabberfiles/edu86.sql.gz
gzip -df /tmp/grabberfiles/edu86.sql.gz 2> /srv/jssgrabber/logs/jssgrabber.log

if [ $? -ne 0 ]; then
	echo "| There was an error extracting the file." | tee -a /srv/jssgrabber/logs/jssgrabber.log
fi

mysqlMenu_getDatabaseInfo

echo "|-------------------------------------------------------------------------------"
echo "| Restoring the database to '${DBNAME}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| This may take several minutes..."
$MYSQL -e "drop database if exists ${DBNAME}"
$MYSQL -e "create database ${DBNAME}"
$MYSQL ${DBNAME} < /tmp/grabberfiles/edu86.sql
$MYSQL -e "grant all on ${DBNAME}.* to '${DBUSER}'@localhost identified by '${DBPASS}'"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The EDU database has been restored to '${DBNAME}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| Permissions have been granted for the user '${DBUSER}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| with the password '${DBPASS}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log

mysqlMenu_writeDatabaseXML

echo "|-------------------------------------------------------------------------------"
}

#*****************************************************************************************

function mysqlMenu_import {
echo "|-------------------------------------------------------------------------------"
echo "| This will import a MySQL database file from a host Mac's '/Users/Shared/'"
echo "| directory and restore the database to MySQL in the virtual machine. You may"
echo "| upload (g)zipped archives (.sql.zip or .sql.gz) and normal SQL files (.sql)."
sshConnection
mysqlMenu_import_transfer
mysqlMenu_mysqlAuthenticate
fileType="${FILENAME#*.}"
if [ "${fileType}" = "gz" ]; then
	echo "|-------------------------------------------------------------------------------"
	echo "| Decompressing Gzip'd SQL file..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	gzip -df /tmp/grabberfiles/"${FILENAME}"
	SQLNAME="${FILENAME%???}"
elif [ "${fileType}" = "zip" ]; then
	echo "|-------------------------------------------------------------------------------"
	echo "| Decompressing the Zipped SQL file..." | tee -a /srv/jssgrabber/logs/jssgrabber.log
	unzip -oq /tmp/grabberfiles/"${FILENAME}" *.sql* -x *._* -d /tmp/grabberfiles/
	SQLNAME=$(find /tmp/grabberfiles/ -name "*.sql")
	SQLNAME="${SQLNAME:5}"
fi
mysqlMenu_getDatabaseInfo
echo "|-------------------------------------------------------------------------------"
echo "| Restoring the imported database to '${DBNAME}'." | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| This may take several minutes..."
$MYSQL -e "drop database if exists ${DBNAME}"
$MYSQL -e "create database ${DBNAME}"
$MYSQL "${DBNAME}" < /tmp/grabberfiles/"${SQLNAME}"
$MYSQL -e "grant all on ${DBNAME}.* to '${DBUSER}'@localhost identified by '${DBPASS}'"
$MYSQL -e "drop table if exists ${DBNAME}.users"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The imported database has been restored to '${DBNAME}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| Permissions have been granted for the user '${DBUSER}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| with the password '${DBPASS}'" | tee -a /srv/jssgrabber/logs/jssgrabber.log
mysqlMenu_writeDatabaseXML
}

#*****************************************************************************************

function mysqlMenu_import_transfer {
sshConnection
echo "|------------------------------------------------------------------------------|"
read -p "| Enter the local path (on the Mac) to your database file: " FILENAME
echo "|------------------------------------------------------------------------------|"
echo "| Enter the password for the account on the host Mac."
echo "| You may be prompted concerning the authenticity of the Mac you are connecting to."
echo "| Please enter \"yes\" if you are."
echo "|------------------------------------------------------------------------------|"
scp "${USERNAME}"@"${MACNAME}":/Users/Shared/"${FILENAME}" /tmp/grabberfiles/ 2> /dev/null
if [ $? -ne 0 ]; then
	echo "|------------------------------------------------------------------------------|"
	echo "| You have entered an incorrect file name. Please try again."
	mysqlMenu_import_transfer
fi
}

#*****************************************************************************************

function mysqlMenu_duplicate {
echo "|-------------------------------------------------------------------------------"
mysqlMenu_mysqlAuthenticate
mysqlMenu_duplicate_select
mysqlMenu_getDatabaseInfo
echo "|-------------------------------------------------------------------------------"
echo "| Restoring the '${SRCDATABASE}' database to '${DBNAME}'."
echo "| This may take several minutes..."
$MYSQL -e "drop database if exists ${DBNAME}"
$MYSQL -e "create database ${DBNAME}"
$MYSQLDUMP "${SRCDATABASE}" > /tmp/grabberfiles/"${SRCDATABASE}".sql
$MYSQL "${DBNAME}" < /tmp/grabberfiles/"${SRCDATABASE}".sql
$MYSQL -e "grant all on ${DBNAME}.* to '${DBUSER}'@localhost identified by '${DBPASS}'"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The database has been restored to \"${DBNAME}\"."
echo "| Permissions have been granted for the user \"${DBUSER}\""
echo "| with the password \"${DBPASS}\"."
mysqlMenu_writeDatabaseXML
echo "|-------------------------------------------------------------------------------"
}

#*****************************************************************************************

function mysqlMenu_duplicate_select {
echo "================================================================================"
echo "| Please enter the name of the database you with to duplicate:"
echo "|-------------------------------------------------------------------------------"
read -p "| Database Name: " SRCDATABASE
$MYSQL -e "use ${SRCDATABASE};"
if [ $? -gt 0 ]; then
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
	echo "| The entered database does not exist. Please try again."
	mysqlMenu_duplicate_select
fi
}

#*****************************************************************************************

function mysqlMenu_new {
mysqlMenu_mysqlAuthenticate
mysqlMenu_getDatabaseInfo
echo "|-------------------------------------------------------------------------------"
echo "| Creating the new database '${DBNAME}'."
$MYSQL -e "drop database if exists ${DBNAME}"
$MYSQL -e "create database ${DBNAME}"
$MYSQL -e "grant all on ${DBNAME}.* to '${DBUSER}'@localhost identified by '${DBPASS}'"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The new database \"${DBNAME}\" has been created."
echo "Permissions have been granted for the user \"${DBUSER}\""
echo "| with the password \"${DBPASS}\"."
if [ "${noJSS}" = "true" ]; then
		echo "|-------------------------------------------------------------------------------"
		break
	else
		mysqlMenu_writeDatabaseXML
fi
}

#*****************************************************************************************

function mysqlMenu_connect_local {
if [ "${noJSS}" = "true" ]; then
		echo "|-------------------------------------------------------------------------------"
		echo "| You did not deploy a JSS, there is no Database.xml file to write to."
		break
fi
mysqlMenu_getDatabaseInfo
mysqlMenu_writeDatabaseXML
}

#*****************************************************************************************

function mysqlMenu_connect_remote {
if [ "${noJSS}" = "true" ]; then
		echo "|-------------------------------------------------------------------------------"
		echo "| You did not deploy a JSS, there is no Database.xml file to write to."
		break
fi
echo "|-------------------------------------------------------------------------------"
echo "| Enter the hostname or IP address of the server where the MySQL database"
read -p "| resides: (leave blank for the default 'localhost'): " SERVERNAME
if [ -z "${SERVERNAME}" ]; then
	DBNAME="localhost"
fi
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
read -p "| Enter the connection port (leave blank for the default '3306'): " SERVERPORT
if [ -z "${SERVERPORT}" ]; then
	DBNAME="3306"
fi
REMOTEDB="true"
mysqlMenu_getDatabaseInfo
mysqlMenu_writeDatabaseXML
}

#*****************************************************************************************

function mysqlMenu_getDatabaseInfo {
echo "|-------------------------------------------------------------------------------"
echo "| Enter the name of the MySQL database."
read -p "| (leave blank for the default 'jamfsoftware'): " DBNAME
if [ -z "${DBNAME}" ]; then
	DBNAME="jamfsoftware"
fi
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| Enter the name for the MySQL database user."
read -p "| (leave blank for the default 'jamfsoftware'): " DBUSER
if [ -z "${DBUSER}" ]; then
	DBUSER="jamfsoftware"
fi
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| Enter the password for the MySQL database user."
read -p "| (leave blank for the default 'jamfsw03'): "  DBPASS
if [ -z "${DBPASS}" ]; then
	DBPASS="jamfsw03"
fi
}

#*****************************************************************************************

function mysqlMenu_writeDatabaseXML {
if [ "${noJSS}" = "true" ]; then
	echo "|-------------------------------------------------------------------------------"
	break
fi

touch /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}"
cat /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/xml/"${jssDatabaseXML}" >> /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}"
echo "|-------------------------------------------------------------------------------"
echo "| Creating a backup of ${jssDatabaseXML} to:"
echo "| /srv/jssgrabber/configbackups/${jssContextName}/${jssDatabaseXML}"
cp -f /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}" /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}".backup
echo "|-------------------------------------------------------------------------------"

if [ "${REMOTEDB}" = "true" ]; then
	echo "| Writing server changes to the ${jssDatabaseXML} file."
	sed -i'' -e "s#<ServerName>localhost</ServerName>#<ServerName>$SERVERNAME</ServerName>#g" /tmp/grabberfiles/"${jssContextName}"/"${jssDatabaseXML}"
	sed -i'' -e "s#<ServerPort>3306</ServerPort>#<ServerPort>$SERVERPORT</ServerPort>#g" /tmp/grabberfiles/"${jssContextName}"/"${jssDatabaseXML}"
fi

echo "| Writing database changes to the ${jssDatabaseXML} file."
sed -i'' -e "s#<DataBaseName>jamfsoftware</DataBaseName>#<DataBaseName>$DBNAME</DataBaseName>#g" /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}"
sed -i'' -e "s#<DataBaseUser>jamfsoftware</DataBaseUser>#<DataBaseUser>$DBUSER</DataBaseUser>#g" /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}"
sed -i'' -e "s#<DataBasePassword>jamfsw03</DataBasePassword>#<DataBasePassword>$DBPASS</DataBasePassword>#g" /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}"
mv -f /srv/jssgrabber/configbackups/"${jssContextName}"/"${jssDatabaseXML}" /var/lib/tomcat7/webapps/"${jssContextName}"/WEB-INF/xml/"${jssDatabaseXML}"
}

#*****************************************************************************************
#*****************************************************************************************

function sshConnection {
echo "|==============================================================================="
echo "| Please enter the following information for SSH connections:"
echo "|-------------------------------------------------------------------------------"
read -p "| Mac's Hostname: " sshMacName
read -p "| Mac's Username: " sshUsername
read -sp "| User Password: " sshPassword
echo ""
sshpass -p "${sshPassword}" ssh -o StrictHostKeyChecking=no "${sshUsername}"@"${sshMacName}" "echo" 2> /dev/null
if [ $? -ne 0 ]; then
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
	echo "| Unable to authenticate to your Mac. Please try again."
	sshConnection
fi
}

#*****************************************************************************************
#*****************************************************************************************

function configMenu {
echo ""
showMenu () {
	echo "================================================================================"
	echo "| JSSGrabber Server Configuration Menu:                                        |"
	echo "|==============================================================================|"
	echo "| 1) Change the JSSGrabber Hostname                                            |"
	echo "| 2) Change the 'jamf' Account Password                                        |"
	echo "| 3) Change the MySQL 'root' Password                                          |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 4) Restore the Tomcat 'server.xml' File (enable for Certificate Manager)     |"
	echo "| 5) Restore the AFP (Netatalk) Configuration Files (Coming Soon v7.1)         |"
	echo "| 6) Restore the SMB Configuration File (Coming Soon v7.2)                     |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| 7) Attempt VM Networking Configuration Repair                                |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| X) Return to the Main Menu                                                   |"
	echo "|==============================================================================="
}
while [ 1 ]
do
	showMenu
	read -p "| Your selection: " CHOICE
	case "$CHOICE" in
		"1") configMenu_hostname; break;;
		"2") configMenu_jamfPass; break;;
		"3") configMenu_mysqlPass; break;;
		"4") configMenu_restoreServerXML; break;;
		"5") configMenu_restoreAFPconfig; break;;
		"6") configMenu_restoreSMBconfig; break;;
		"7") configMenu_repairVMnetworking; break;;
		"x"|"X") break;;
	esac
done
MAINMENU
}

#*****************************************************************************************

function configMenu_hostname {
echo ""
echo "==============================================================================="
echo "| WARNING: Changing the hostname of your JSSGrabber will require a reboot. You"
echo "| will need to make appropriate changes to all deployed JSS contexts to reflect"
echo "| the new hostname as well as create new web certificates if any exist."
echo "|------------------------------------------------------------------------------"
read -p "| Yes/No: " CHOICE
case "$CHOICE" in
		"y"|"Y"|"YES"|"Yes"|"yes") ;;
		"n"|"N"|"NO"|"No"|"no") break;;
esac

hostnameCurrent=$(hostname)
echo "|------------------------------------------------------------------------------"
read -p "| Enter the new hostname for the JSSGrabber: " hostnameNew
echo "| Modifying the '/etc/hosts' and '/etc/hostname' files..."
sed -i'' -e "s#${hostnameCurrent}#${hostnameNew}#g" /etc/hosts
sed -i'' -e "s#${hostnameCurrent}#${hostnameNew}#g" /etc/hostname
echo "|------------------------------------------------------------------------------"
echo "| Rebooting now..."
sleep 3
reboot
}

#*****************************************************************************************

function configMenu_jamfPass {
echo ""
passwd jamf
if [ "$?" -ne 0 ]; then
	echo ""
	configMenu_jamfPass
fi
}

#*****************************************************************************************

function configMenu_mysqlPass {
mysqlAuth
echo ""
mysqladmin password -uroot -p"${MYSQLRPASS}"
if [ $? -ne 0 ]; then
	echo ""
	configMenu_mysqlPass
fi
}

#*****************************************************************************************

function configMenu_restoreServerXML {
echo ""
echo "|-------------------------------------------------------------------------------"
if [ ! -e /srv/jssgrabber/configbackups/server.xml.backup ]; then
	echo "| There is no backup of the 'server.xml' file to restore."
	echo "================================================================================"
	read -sp "| Press [ENTER] to return to the Main Menu..."
	echo ""
	break
fi

echo "| Restoring the 'server.xml' file"
rm /var/lib/tomcat7/conf/server.xml
cp /srv/jssgrabber/configbackups/server.xml.backup /var/lib/tomcat7/conf/server.xml
chown tomcat7:tomcat7 /var/lib/tomcat7/conf/server.xml

echo "|-------------------------------------------------------------------------------"
echo "| Do you wish to enable the 8443 connector for Tomcat?"
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| NOTE: you must select this option if you wish to use the 'Certificate Manager'"
echo "| for generating web certificates for your JSS contexts."
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| Choose 'No' if you wish to configure Tomcat manually."
echo "|-------------------------------------------------------------------------------"
read -p "| Yes/No: " CHOICE
case "$CHOICE" in
		"y"|"Y"|"YES"|"Yes"|"yes") ;;
		"n"|"N"|"NO"|"No"|"no") echo "User has cancelled deletion."; break;;
esac
echo ""

echo "|-------------------------------------------------------------------------------"
echo "| Enabling port 8443 for Tomcat with 'Certificate Manager' information." | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "| Writing changes to the 'server.xml' file." | tee -a /srv/jssgrabber/logs/jssgrabber.log
sed -i'' "s#    <Connector port=\"8443\" protocol=\"HTTP/1.1\" SSLEnabled=\"true\".*# --><Connector port=\"8443\" protocol=\"HTTP/1.1\" SSLEnabled=\"true\"#g" /var/lib/tomcat7/conf/server.xml
sed -i'' "s#               maxThreads=\"150\" scheme=\"https\" secure=\"true\".*#               maxThreads=\"150\" scheme=\"https\" secure=\"true\" keystoreFile=\"/var/lib/tomcat7/keystore.jks\" keystorePass=\"grabberPass\"#g" /var/lib/tomcat7/conf/server.xml
sed -i'' "s#               clientAuth=\"false\" sslProtocol=\"TLS\" />.*#               clientAuth=\"false\" sslProtocol=\"TLS\" /> <!--#g" /var/lib/tomcat7/conf/server.xml
echo "|-------------------------------------------------------------------------------"
echo "| The Tomcat 'server.xml' file has been restored." | tee -a /srv/jssgrabber/logs/jssgrabber.log
echo "|==============================================================================="
read -sp "| Press [ENTER] to return to the Main Menu..."
echo ""

}

#*****************************************************************************************

function configMenu_repairVMnetworking {
echo ""
echo "|-------------------------------------------------------------------------------"
echo "| If you are moving between different networks frequently your VM may encounter"
echo "| a situation where it is unable to obtain an IP address. This action will"
echo "| remove network configuration rules which may be causing the conflict."
echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"
echo "| The VM must reboot for the changes to take effect. Do you wish to proceed?"
echo "|-------------------------------------------------------------------------------"
read -p "| Yes/No: " CHOICE
case "$CHOICE" in
		"y"|"Y"|"YES"|"Yes"|"yes") ;;
		"n"|"N"|"NO"|"No"|"no") echo "User has cancelled deletion."; break;;
esac
echo ""
rm /etc/udev/rules.d/70-persistent-net.rules
serverShutdown_reboot
}

#*****************************************************************************************
#*****************************************************************************************

function jssManager {
/usr/bin/jssmanager
echo ""
}

#*****************************************************************************************
#*****************************************************************************************

function distroManager {
/usr/bin/distromanager
echo ""
}

#*****************************************************************************************
#*****************************************************************************************

function certManager {
/usr/bin/certmanager
echo ""
}

#*****************************************************************************************
#*****************************************************************************************
function manPage {
echo "================================================================================"
echo "| While viewing the man page for the JSSGrabber VM, use the arrow keys to move |"
echo "| UP and DOWN one line at a time. Press [SPACEBAR] to jump ahead, press [B] to |"
echo "| jump back, and press [Q] to return to the MAIN MENU.                         |"
echo "|==============================================================================|"
read -sp "| Press [ENTER] to continue...|"
echo ""
man /usr/share/man/man1/jamf.1.gz
echo ""
}

#*****************************************************************************************
#*****************************************************************************************

function viewSource {
echo ""
showMenu () {
	echo "================================================================================"
	echo "| While viewing the source code for each program, use the arrow keys to move   |"
	echo "| UP and DOWN one line at a time. Press [SPACEBAR] to jump ahead, press [B] to |"
	echo "| jump back, and press [Q] to return to the MAIN MENU.                         |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| WARNING: Pressing the [V] key will enable editing mode.                      |"
	echo "|------------------------------------------------------------------------------|"
	echo "| View Source Code For:                                                        |"
	echo "|==============================================================================|"
	echo "| 1) JSSGrabber                                                                |"
	echo "| 2) JSS Manager                                                               |"
	echo "| 3) Distribution Point Manager                                                |"
	echo "| 4) Certificate Manager                                                       |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| X) Return to Main Menu                                                       |"
	echo "================================================================================"
}
while [ 1 ]
do
	showMenu
	read -p "| Your selection: " CHOICE
	case "$CHOICE" in
		"1") less /usr/bin/jssgrabber; break;;
		"2") less /usr/bin/jssmanager; break;;
		"3") less /usr/bin/distromanager; break;;
		"4") less /usr/bin/certmanager; break;;
		"x"|"X") break;;
	esac
done
}

#*****************************************************************************************
#*****************************************************************************************

function jamfUpdate {
/usr/bin/jamfupdate
echo ""
echo "Exiting JSSGrabber. Run 'sudo jssgrabber' to relaunch with latest version."
echo ""
exitProgram
}

#*****************************************************************************************
#*****************************************************************************************
function restartTomcat {
echo "|-------------------------------------------------------------------------------"
service tomcat7 restart
echo "| Tomcat has been restarted."
echo "|-------------------------------------------------------------------------------"
read -sp "| Press [ENTER] to continue..."
echo ""
}

#*****************************************************************************************
#*****************************************************************************************

function exitProgram {
echo "" >> /srv/jssgrabber/logs/jssgrabber.log
echo "Exiting the JSSGrabber." >> /srv/jssgrabber/logs/jssgrabber.log
exit 0
}

#*****************************************************************************************
#*****************************************************************************************

function serverShutdown {
echo ""
showMenu () {
	echo "================================================================================"
	echo "| Do you wish to SHUTDOWN or REBOOT your JSSGrabber Server?                    |"
	echo "|==============================================================================|"
	echo "| S) Shutdown                                                                  |"
	echo "| R) Reboot                                                                    |"
	echo "| -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - |"
	echo "| X) Cancel and return to the Main Menu                                        |"
	echo "|==============================================================================="
}
while [ 1 ]
do
	showMenu
	read -p "| Your selection: " CHOICE
	case "$CHOICE" in
		"s"|"S") serverShutdown_shutdown; break;;
		"r"|"R") serverShutdown_reboot; break;;
		"x"|"X") break;;
	esac
done
}

#*****************************************************************************************

function serverShutdown_shutdown {
echo "JSSGrabber server is shutting down." >> /srv/jssgrabber/logs/jssgrabber.log
shutdown -P now &
exit 0
}

#*****************************************************************************************

function serverShutdown_reboot {
echo "JSSGrabber server is rebooting." >> /srv/jssgrabber/logs/jssgrabber.log
shutdown -r now &
exit 0
}

#*****************************************************************************************
#*****************************************************************************************

echo ""
echo "================================================================================"
echo "| JSSGrabber v7.0b                                                             |"
echo "|------------------------------------------------------------------------------|"
echo "| Welcome to your JAMF Software Server.                                        |"
echo "|                                                                              |"
echo "| This VM is provided as a demoing, testing and support tool to aid you.       |"
echo "|------------------------------------------------------------------------------|"
echo "| The programs provided with this VM automate much of the setup and            |"
echo "| configuration of JSS contexts, MySQL databases, and local distribution       |"
echo "| points. It is intended for JAMF staff who are already proficient at multi-   |"
echo "| -platform server setups and JSS installations (manual and with installers).  |"
echo "|------------------------------------------------------------------------------|"
echo "| It is recommended you have completed the following before using this VM:     |"
echo "| RookBook Lesson Plan                                                         |"
echo "| CMA (Certified Mobile Administrator)                                         |"
echo "| CCA (Certified Casper Administrator)                                         |"
echo "| CJA (Certified JSS Administrator)                                            |"
echo "================================================================================"
read -sp "| Press [ENTER] to continue...                                                 |"
echo ""

while true; do
	mainMenu
done

exit 0