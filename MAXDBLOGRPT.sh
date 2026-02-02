#!/bin/bash
##################################################################################################
# Author: Kevin Fries
# This script is intended to monitor the autolog/autosave parameter 
# as well as the database and log percentage used of a Live Cache or MaxDB database.
# This requires only the Database SID as a parameter. We leverage the XUSER to perform 
# the authorizations for the commands. The commands are not invasive and change nothing. 
# Actions that need to be taken with be logged and also sent as part of an email.
# We will also ensure that the environment and other diagnostic information is sent back to 
# minimize confusion. 
# All actions will be logged in a daily file and these will be cleaned up for any
# timestamp older than $FILE_EXPIRATION days.
# 1. Verify the usage and produce a help page if the input is missing. 
# 2. Verify the database is up and running. If not exit cleanly. We need not proceed further.
# 3. Check the autolog/autosave parameter otherwise proceed
# 4. If the autosave/autolog parameter is set to  "AUTOSAVE" proceed to log the results
# 5. We also want to record the percentage of the log used and whether the DB is full. 
# 6. If there's a problem with the $LOG_THRESHOLD being greater than 35%, add to an email
# 7. If there's a problem with autolog/autosave being set to off, add to email
# 8. We also want to send the email if the DB is at 100 percent - 
#     the alert level will be adjusted depending on overall space
# 9. Housekeeping - clean up old log files. 
#########################################################################################################
# It's a simple matter to attempt to turn AUTOSAVE on but this is expected to be something that
# should be investigated rather than automated since the causes of this should be remediated first.
# As such, intructions are provided in the email. 
#########################################################################################################
# Allow any files to be read, created and removed as needed
umask 000
#########################################################################################################
# Let's sanitize the input and verify everything exists. We need a database SID passed along 
# because the reporting and logging depend on this. So verify the parameter is passed
# If parameter is not passed, exit immediately.
# I haven't created any parameter for debugging at this point but it's child's play to add. 
#########################################################################################################
if [ "$#" -lt 1 ]
then
  echo "No arguments supplied - Requires the database SID as an argument" 
  echo "Please use the format "script.sh SID" EG: maxdblogstatus.sh DMP"
  exit 1
fi
# Environment
CUR_SID=$1
CUR_DATE=`date +%Y-%m-%d_%H-%M-%S`
#LOG_FILE=$CUR_SID"-MAXDBLOGSTATUS-"$CUR_DATE".log" # testing only
CUR_USER=`whoami`
FILE_EXPIRATION=35
CUR_HOST=`hostname`
SCRIPT_NAME=$0
# Mail values for Subject and where it's sent
SUBJECT=`echo ${UC_CUR_SID} " on " ${CUR_HOST} " Alert Report"`
TO="Kevin_fries@colpal.com,esc_dba_group@colpal.com,esc_prod_control@colpal.com"

# Possible Values for MAIL_ALERT_LEVEL are NONE, WARNING, CRITICAL - Mail will be sent on any level other than  NONE
MAIL_ALERT_LEVEL=NONE 
#######################################################

# Log threshold is normally 33% when the AUTOSAVE option is turned on.
# Let's set it to 35% just to allow for a high throughput.
# The idea is that having AUTOSAVE off is the real trigger for action
# But it's advisable to note that the logs have grown past what normally triggers AUTOSAVE
LOG_THRESHOLD=35

# We're setting DATABASE_THRESHOLD at 98 - this is intended for a 5TB system which is approximately 100GB free
# Adjust downward for smaller databases. Existing monitors should pick this up and report it anyway. 
DATABASE_THRESHOLD=98

# We also want to monitor that the database is not at 100% full. 
#################################################################
# Debugging Information
################################################################
echo "$1" "First argument"
echo $CUR_USER "Current user"
echo $CUR_HOST "Current host"
echo $CUR_DATE "Current date"
echo $CUR_SID "current SID"
echo $LOG_FILE
###########################################################
# Let's check the input and make sure it's in upper case
##########################################################
echo $CUR_SID "Input SID before"
UC_CUR_SID=$(echo "$CUR_SID" | awk '{print toupper($0)}')
echo $UC_CUR_SID "Input SID as uppercase_string"
#####################################
# Ensure the database is available, otherwise exit without error
#####################################
if dbmcli -U "${UC_CUR_SID}BACKUP" db_state |grep -q 'ONLINE';
then DB_UP='${UC_CUR_SID} "Online"'
echo "DB is online - script continues"
else DB_UP='${UC_CUR_SID} "Unavailable"';
echo $UC_CUR_SID " DB is not online"
exit 0
fi
###################################################
# All the housekeeping tests have been passed. Let's set up the output files for logging commands 
##################################################
PWD=`pwd`
echo $PWD
LOG="log"
echo  ${PWD}/${LOG}
DATEYMDSEC=`date` ## This is intended for a more precise timestamp
DATEYMD=`date +%Y%m%d` ## This is intended for a less precise timestamp 

# UC_CUR_SID should never be blank at this point 
LOG_FILE=$UC_CUR_SID"-MAXDBLOGRPT-"$DATEYMD".log"

# Let's make sure the current script directory has a log subdirectory under it. 
if ! [ -e ${PWD}/${LOG} ]; then
  echo "Directory does not exist."
mkdir log
echo "Creating log directory"
chmod 775 ${PWD}/${LOG}
else
echo "Log directory exists: " ${PWD}/${LOG}
fi

# As this is a daily file, let's make sure a file exists, if not create it
if ! [ -e ${PWD}/${LOG}/${LOG_FILE} ]; then
  echo "Directory exists but file does not exist, creating file: " ${PWD}/${LOG}/${LOG_FILE}
  touch ${PWD}/${LOG}/${LOG_FILE}
else
echo "Directory and file exists. Appending results to: "  ${PWD}/${LOG}/${LOG_FILE}
touch ${PWD}/${LOG}/${LOG_FILE}
fi

#################################################################################################
# Lets find out the percentage of the database that allocated from the datafiles
#######################################################################################################
DATABASEUSED=`dbmcli -U "${UC_CUR_SID}BACKUP" info state| grep 'Data'|grep '%'|grep  -v 'Perm'|grep -v 'Temp'|awk 'NR==1{print $4}'`
#echo  $DATABASEUSED " = database percentage used dammit"
if [ "${DATABASEUSED}" -gt "${DATABASE_THRESHOLD}" ];
then
echo "Database used percentage greater than $DATABASE_THRESHOLD - Please check space used on database $UC_CUR_SID"
MAIL_ALERT_LEVEL="CRITICAL"
else
echo "${DATABASEUSED}" " = Database Used Percentage"
echo "Database used percentage less than $DATABASE_THRESHOLD on database $UC_CUR_SID"
fi

#########################################################################################
# OK, let's get the log usage from the system! 
#########################################################################################
USED_LOG_SIZE=`dbmcli -U "${UC_CUR_SID}BACKUP" info log|grep -i 'Used Size'| grep '%'|awk '{print $5}'`
echo "Used Log Size: " $USED_LOG_SIZE
if [ "${USED_LOG_SIZE}" -gt "${LOG_THRESHOLD}" ];
then
echo "Log size exceeded 35% - possible autosave of MAXDB logs may be disabled";
MAIL_ALERT_LEVEL="WARNING"
else
echo "Log size less than 35% - not critical at this point"
fi

##########################################################
# Here's the important part of this - We want to know if AUTOSAVE is turned off. This ordinarily should not happen.
############################################################
AUTOSAVE_LOG_STATUS=`dbmcli -U "${UC_CUR_SID}BACKUP" autolog_show |grep -i 'AUTOSAVE'| awk '{print $1}'`
echo "autosave status: " $AUTOSAVE_LOG_STATUS
if [[ $AUTOSAVE_LOG_STATUS == 'AUTOSAVE' ]];
then
echo $AUTOSAVE_LOG_STATUS " AUTOSAVE is on - continuing on"
else
echo  $AUTOSAVE_LOG_STATUS " AUTOSAVE not running"
MAIL_ALERT_LEVEL="CRITICAL"
fi

#################################
# Let's set up reporting and add to the file.
# Files will be in the home directory where the script is running  and in the log subdirectory
# If the script runs more than once a day, and it should, we'll append to the file.
# Please note that if the script is running for multiple databases, theere will be multiple files.

echo "Begin *********************************************************************" >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Date and Time of Run:    " $CUR_DATE >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Script Name              " $SCRIPT_NAME >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Database SID:            " $UC_CUR_SID >> ${PWD}/${LOG}/${LOG_FILE}
echo "Current user:            " $CUR_USER >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Current host:            " $CUR_HOST >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Results:                 "           >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Database Used Size:      " "${DATABASEUSED}" >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Used Log Size:           " "${USED_LOG_SIZE}" >>  ${PWD}/${LOG}/${LOG_FILE}
echo "AUTOSAVE Status          " $AUTOSAVE_LOG_STATUS >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Email Alert Level        " $MAIL_ALERT_LEVEL >>  ${PWD}/${LOG}/${LOG_FILE}
echo "End  ***********************************************************************" >>  ${PWD}/${LOG}/${LOG_FILE}

##########################################
# EMAIL Overrides! - Testing only, please ernsure these are commented out before making live
#############################################
# For debugging mail and making sure it's sent for testing, activate the below variable values as needed. 
# Otherwise leave commented out as they will send out mails that may be acted upon
# erroneously. Be sure to change the email address for your own testing. Don't make Kevin mad. 
# MAIL_ALERT_LEVEL="CRITICAL"
# MAIL_ALERT_LEVEL="WARNING"
# DATABASEUSED=99
# DATABASEUSED=100
# AUTOSAVE_LOG_STATUS="OFF"
# USED_LOG_SIZE=36
# TO="Kevin_fries@colpal.com"

###########################
# Do we have issues? Let's log them and also generate a mail if necessary
#############################################

if [[ "${MAIL_ALERT_LEVEL}" != "NONE" ]] ;
then
SUBJECT=`echo  ${UC_CUR_SID} " on " ${CUR_HOST} " Alert Report "`  
TO=$TO
BODY=`cat <<EOF

$MAIL_ALERT_LEVEL alert for Database $CUR_SID on $CUR_HOST
This Email Report is only Generated on Warning or Critical level - Contact DBA if a production system
A daily physical log of actions can be found at ${PWD}/${LOG}/${UC_CUR_SID}-MAXDBLOGRPT*.log
Script Name: $SCRIPT_NAME was run at $DATEYMDSEC

$MAIL_ALERT_LEVEL  alert level found - the following conditions were checked and need attention.

Database Used Percentage =    ${DATABASEUSED}
Used Log Size:           =    $USED_LOG_SIZE
AUTOSAVE Log Status      =    $AUTOSAVE_LOG_STATUS

1. Autosave of logs enabled: $AUTOSAVE_LOG_STATUS - If this is set to anything but AUTOSAVE, DBA needs to investigate the issue immediately.
                                                    Possible causes are that the backup directory is full or some other catastrophic event.
       
    To activate AUTOSAVE, run the following ONLY AFTER fixing the cause:

       A: Log into the $CUR_HOST as the user sdb eg: dzdo su - sdb
 
       B: Check the status by: dbmcli -U ${UC_CUR_SID}BACKUP autolog_show
 
       C: turn on AUTOSAVE by the following command: 
             1. dbmcli -U ${UC_CUR_SID}BACKUP autolog_on 
  
       D: Verify the database state and the AUTOSAVE status after a few minutes via
             1. Check the autosave status = AUTOSAVE
                  dbmcli -U ${UC_CUR_SID}BACKUP autolog_show
             2. Make sure it's up (status = ONLINE) (ADMIN status will not be sufficient!) 
                  dbmcli -U ${UC_CUR_SID}BACKUP db_state 
             3. Check the log percentage used if you want.
                  dbmcli -U ${UC_CUR_SID}BACKUP info log|grep -i 'Used Size'| grep '%'|awk '{print $5}'

2. Database percentage used: $DATABASEUSED - If this is 100 percent you have an serious issue and need to allocate a new datafile.
                                             While the monitors should catch this, it's not a bad idea to check if the database
                                             needs additional datafiles.

3. Log percentage used:      $USED_LOG_SIZE  - If this is over 35 percent, it needs to be investigated.


-----------------------------------------------------------------------------------------
This is normally invoked by the root crontab on the server, see that for further details. 
This e-mail was automatically generated by $0 on $CUR_HOST. Please do not reply.

EOF`

`mail -s "$SUBJECT" "$TO" <<EOF

$BODY`

EOF 2>/dev/null
fi
#############################################################
# Let's do some housekeeping on the log files - 35 days by default
####################################
# find ${PWD}/${LOG} -name "${UC_CUR_SID}-MAXDBLOGRPT*.log" -mmin +7 -exec ls -l '{}' \;  
echo "##  "Beginning cleanup of logfiles older than ${FILE_EXPIRATION} days" ###########" >>  ${PWD}/${LOG}/${LOG_FILE}
echo "Beginning cleanup of logfiles older than ${FILE_EXPIRATION} days"
echo "Cleaning up old log files over ${FILE_EXPIRATION} days" >>  ${PWD}/${LOG}/${LOG_FILE}
echo "find ${PWD}/${LOG} -type f -name ${UC_CUR_SID}-MAXDBLOGRPT*.log -mtime +${FILE_EXPIRATION} -exec rm -f '{}' \;" >>  ${PWD}/${LOG}/${LOG_FILE}
find ${PWD}/${LOG} -name "${UC_CUR_SID}-MAXDBLOGRPT*.log" -mtime +${FILE_EXPIRATION} -exec rm -f '{}' \;
echo "##  "Cleanup of logfiles older than ${FILE_EXPIRATION} days completed" ###########" >>  ${PWD}/${LOG}/${LOG_FILE}
