#!/bin/bash
##########################################################################################
function MAINMENU {
touch /tmp/webapplist.txt
ls /var/lib/tomcat7/webapps/ > /tmp/webapplist.txt
echo ""
echo "==============================================================================="
echo "| Your VM's JSS Manager                                                       |"
echo "|=============================================================================|"
echo "| Context Name            | JSS Version             | Database In Use         |"
echo "|=========================|=========================|=========================|"
while read WEBAPP; do
	VERSION=$(cat /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/version.xml 2> /dev/null | awk -F"<|>" '/<jamfWebApplication>/ { getline;print $3 }')
	if [ -z "${VERSION}" ]; then
		VERSION=$(cat /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/version.xml 2> /dev/null | awk -F"<|>" '/jamfWebApplication/ { getline;getline;print $3 }')
	fi
	databaseAWK
	WEBAPP="| "$(printf "%-24s" "${WEBAPP}")
	if [ -z "${VERSION}" ]; then
		VERSION="NA"
	fi
	VERSION="| "$(printf "%-24s" "${VERSION}")
	if [ -z "${DATABASE}" ]; then
		DATABASE="NA"
	fi
	DATABASE="| "$(printf "%-24s" "${DATABASE}")"|"
	echo "${WEBAPP}${VERSION}${DATABASE}"
	echo "|- - - - - - - - - - - - -|- - - - - - - - - - - - -|- - - - - - - - - - - - -|"
	VERSION=""
	DATABASE=""
done < /tmp/webapplist.txt
rm /tmp/webapplist.txt
read -sp "Press [ENTER] to continue . . . "
echo ""
echo ""
echo "==============================================================================="
echo "| Please select an option:                                                    |"
echo "==============================================================================="
showMenu () {
	echo "| 1) Delete a JSS context                                                     |"
	echo "| 2) Delete a MySQL Database                                                  |"
	echo "| 3) Delete a JSS context -AND- its MySQL Database                            |"
	echo "|  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  |"
	echo "| X) Exit the JSS Manager                                                     |"
	echo "-------------------------------------------------------------------------------"
	echo ""
}
while [ 1 ]
do
	showMenu
	read -p "Your selection: " CHOICE
	case "$CHOICE" in
		"1") doBoth="false"; deleteJSS; break;;
		"2") doBoth="false"; deleteDatabase; break;;
		"3") doBoth="true"; deleteJSS; break;;
		"x" | "X") EXITSCRIPT; break;;
	esac
done
MAINMENU
}
##########################################################################################
function EXITSCRIPT {
echo ""
exit 0
}
##########################################################################################
function mysqlAuth {
echo ""
read -sp "Please enter the root password for MySQL (leave blank if there is none): " MYSQLRPASS
MYSQL="/usr/bin/mysql -u root"
if [ ! -z "$MYSQLRPASS" ]; then
     MYSQL="${MYSQL} -p${MYSQLRPASS}"
fi
$MYSQL -e ";"
if [ $? -gt 0 ]; then
	echo ""
	echo "Incorrect root password entered. Please try again."
	mysqlAuth
fi
echo ""
echo "MySQL authentication successful"
}
##########################################################################################
function jssSelect {
echo ""
read -p "Enter the name of the JSS context you wish to delete: " WEBAPP
if [ ! -d /var/lib/tomcat7/webapps/"${WEBAPP}"/ ]; then
	echo ""
	echo "You have entered an incorrect JSS context name. Please try again."
	jssSelect
elif [ -z "${WEBAPP}" ]; then
	echo ""
	echo "You cannot enter a blank value for the JSS context."
	jssSelect
fi
}
##########################################################################################
function databasePROMPT {
echo ""
read -p "Enter the name of the MySQL Database you wish to delete: " DATABASE
if [ -z "${DATABASE}" ]; then
	echo ""
	echo "You have not entered a MySQL Database name. Please try again."
	databasePROMPT
fi
mysqlAuth
$MYSQL -e "use ${DATABASE}"	
if [ "$?" -ne 0 ]; then
	echo ""
	echo "You has entered an incorrect MySQL Database name. Please try again."
	databasePROMPT
fi
}
##########################################################################################
function databaseAWK {
	if [ -e /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/DataBase.xml ]; then
		DATABASE=$(cat /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/DataBase.xml 2> /dev/null | awk -F"<|>" '/<DataBaseName>/ { print $3 }')
	elif [ -e /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/Database.xml ]; then
		DATABASE=$(cat /var/lib/tomcat7/webapps/"${WEBAPP}"/WEB-INF/xml/Database.xml 2> /dev/null | awk -F"<|>" '/<DataBaseName>/ { print $3 }')
	fi
}
##########################################################################################
function deleteJSS {
jssSelect
if [ "${doBoth}" = "true" ]; then
	mysqlAuth
	echo "Reading the database settings for /${WEBAPP}/ . . ."
	databaseAWK
fi
echo ""
echo "WARNING: You cannot undo this action. Do you still wish to proceed?"
read -p "Yes/No: " CHOICE
case "$CHOICE" in
		"y"|"Y"|"YES"|"Yes"|"yes") ;;
		"n"|"N"|"NO"|"No"|"no") echo "User has cancelled deletion."; break;;
esac
echo ""
echo "Removing the ${WEBAPP} context and files from your server . . ."
echo ""
service tomcat7 stop
rm -rf /var/lib/tomcat7/webapps/"${WEBAPP}"*
if [ -d /var/lib/tomcat7/work/Catalina/localhost/"${WEBAPP}"/ ]; then
	rm -rf /var/lib/tomcat7/work/Catalina/localhost/"${WEBAPP}"*
fi
if [ -d /var/log/"${WEBAPP}"/ ]; then
	rm -rf /var/log/"${WEBAPP}"/
fi
if [ "${doBoth}" = "true" ]; then
	deleteDatabase
fi
TCSTATUS=$(service tomcat7 status | grep "is running")
if [ -z "${TCSTATUS}" ]; then
	echo ""
	service tomcat7 start
fi
echo ""
echo "The JSS context ${WEBAPP} has been removed."
}
##########################################################################################
function deleteDatabase {
if [ "${doBoth}" = "false" ]; then
	databasePROMPT
	echo ""
	echo "WARNING: You cannot undo this action. Do you still wish to proceed?"
	read -p "Yes/No: " CHOICE
	case "$CHOICE" in
		"y" | "Y" | "YES" | "Yes" | "yes") ;;
		"n" | "N" | "NO" | "No" | "no") echo "User has cancelled deletion."; break;;
	esac
fi
if [ -z "${DATABASE}" ]; then
	echo ""
	echo "There is no database associated with this JSS context."
	break
fi
echo ""
echo "Deleting the ${DATABASE} MySQL Database . . ."
$MYSQL -e "drop database if exists ${DATABASE}"
}
##########################################################################################
MAINMENU
exit 0