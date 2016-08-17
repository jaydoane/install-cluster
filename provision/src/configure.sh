#!/bin/bash
# ##################################################################################
# (c) Copyright IBM Corp. 2015
#
# configure.sh Configures a Cloudant Local single node implementation or every 
#              DB and LB node of a multi-node cluster.
#
#              NOTE: This script must be run on any Cloudant Local single node
#                    machine well as every DB and LB node of a Cloudant Local
#                    multi-node cluster.
#                    
#              Before running this script for the first time, you must:
#              1) Modify the co-located companion file:
#                    configure.ini
#                 You must supply values to the variables defined in configure.ini
#                 The values needed are describe before each set of variables.
#              2) Run this file on the first node (or single node) computer.
#              3) For a multi-node implementation:
#              3a) Copy the modified configure.ini file from the first node
#                  to each DB and LB node
#              3b) Run the configure.sh script, using the modified 
#                  configure.ini, on those nodes.
#
# ##################################################################################

# Define the name of the log file
_PROGRAM="configure"
# Delete the Database
_DELETE_DB=n
# FB 44330
# NOTE: -I is an undocumented parameter to allow a configuration to complete
#       even if an error is present.  It should ONLY be used after an attempt
#       is made without -I and the error is deemed to be non-fatal
_DELAYED_IGNORE_ERRORS=0

# Get the directory of this script file
_DIR=$( cd "$( dirname "$0" )" && pwd )

# Include common utilities
source $_DIR/_utils.sh

# Ensure the configuration file exists
if [ ! -f $_DIR/configure.ini ]; then
   _MSG="ERROR: The file configure.ini must exist in the same directory as $0."
   _RC=1
   displayMsgAndExit
fi

# Include user defined properties
source $_DIR/configure.ini

# URL for the stats DB
_STATS_URL=http://localhost:5984/stats
# Indicates of Cloudant should start in maintenance mode
_MAINT_MODE=0
# The cookie value $_DIR/configure.ini
_CFG_COOKIE=${_COOKIE}

# #######################################################################
# Other properties used in this script
# _INSTALL_TYPE = m (multi-name) | s (single-node)
# _THIS_NODE = d1 (first DB node) | db (other DB node) | 
#              l1 (first LB node) | l2 (second LB node) |
#              sn (single node - db1 + lb1)
# #######################################################################

function displayHelp () {
   # NOTE: -I is an undocumented parameter to allow a configuration to complete
   #       even if an error is present.  It should ONLY be used after an attempt
   #       is made without -I and the error is deemed to be non-fatal

   echo " "
   echo "Usage: "
   echo "configure.sh  [option]  [command]"
   echo "              [-h | -q] [-D][-m]"
   echo " "
   echo "Where:"
   echo " option is one of these optional parameters:"
   echo "  -h       = Display this help information and exit"
   echo "  -q       = Run in quiet mode"
   echo " "
   echo " command is one or more of these optional parameters:"
   echo "  -D       = Delete the Cloudant databases"
   echo "  -m       = Leave Cloudant in maintenance mode"
   echo " "

   if [ "$1" == "-h" -o "$1" == "--help" ]; then
      _RC=0
   fi
   exit ${_RC}
}

# ###############################################
# See if any parameters were specified
# ###############################################
if [ ! -z "$1" ]; then
   while getopts hbqmDI OPT; do
      case "$OPT" in
         h) # Did the user ask for help?
            displayHelp;;
         b) # Did the user ask for Debug mode?
            _DEBUG=1;;
         q) # Did the user ask for quiet/silent mode
            _VERBOSE=n;;
         m) # Leave Cloudant in Maintenace mode
            _MAINT_MODE=1;;
         D) # Did the user ask to delete the Cloudant DB
            _DELETE_DB=y;;
         I) # NOTE: -I is an undocumented parameter to allow a configuration to complete
            #       even if an error is present.  It should ONLY be used after an attempt
            #       is made without -I and the error is deemed to be non-fatal
            _DELAYED_IGNORE_ERRORS=1;;
         *) 
            _MSG="ERROR: $* is an unknown parameter"
            _RC=1
            displayHelp;;
      esac
   done
fi

# Determine the OS and Distribution
getOS

# Ensure operator is root or sudo
if [ $(id -u) -ne 0 ]; then
   _MSG="Root access is required to configure Cloudant Local."
   _RC=2
   displayMsgAndExit
fi

if [ -z "${_FILE_VERSION}" ]; then
   _MSG="ERROR : The _FILE_VERSION of the configure.ini is not set."
   displayWarning
   _MSG="ACTION: Use the version of the configure.ini file that accompanied this configure.sh file."
   _RC=3
   displayMsgAndExit
fi

if [ ${_FILE_VERSION} -lt 2 ]; then
   _MSG="ERROR : The _FILE_VERSION of the configure.ini is out of date."
   displayWarning
   _MSG="ACTION: Use the version of the configure.ini file that accompanied this configure.sh file."
   _RC=3
   displayMsgAndExit
fi


if [ -z "${_ADMIN_USER_ID}" ]; then
   _MSG="ERROR : The property _ADMIN_USER_ID must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _ADMIN_USER_ID."
   _RC=4
   displayMsgAndExit
fi

if [ -z "${_ADMIN_PASSWORD}" ]; then
   _MSG="ERROR : The property _ADMIN_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _ADMIN_PASSWORD."
   _RC=4
   displayMsgAndExit
fi

if [ -z "${_CLOUDANT_PASSWORD}" ]; then
   _MSG="ERROR : The property _CLOUDANT_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _CLOUDANT_PASSWORD."
   _RC=5
   displayMsgAndExit
fi

if [ -z "${_ADMIN_ENCRYPTED_PASSWORD}" ]; then
   _MSG="ERROR : The property _ADMIN_ENCRYPTED_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _ADMIN_ENCRYPTED_PASSWORD to _admin_not_set."
   displayWarning
   _MSG="        Then run configure.sh on the first node to set the encrypted value."
   _RC=6
   displayMsgAndExit
fi

if [ -z "${_CLOUDANT_ENCRYPTED_PASSWORD}" ]; then
   _MSG="ERROR : The property _CLOUDANT_ENCRYPTED_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _CLOUDANT_ENCRYPTED_PASSWORD to _cloudant_not_set."
   displayWarning
   _MSG="        Then run configure.sh on the first node to set the encrypted value."
   displayWarning
   _RC=7
   displayMsgAndExit
fi

if [ -z "${_HAPROXY_USER_ID}" ]; then
   _MSG="ERROR : The property _HAPROXY_USER_ID must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _HAPROXY_USER_ID."
   _RC=8
   displayMsgAndExit
fi

if [ -z "${_HAPROXY_PASSWORD}" ]; then
   _MSG="ERROR : The property _HAPROXY_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _HAPROXY_PASSWORD."
   _RC=9
   displayMsgAndExit
fi

if [ -z "${_JMXREMOTE_PASSWORD}" ]; then
   _MSG="ERROR : The property _JMXREMOTE_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _JMXREMOTE_PASSWORD."
   _RC=10
   displayMsgAndExit
fi

if [ -z "${_METRICS_URL}" ]; then
   _MSG="ERROR : The property _METRICS_URL must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_URL."
   _RC=9
   displayMsgAndExit
fi

if [ -z "${_METRICS_DBNAME}" ]; then
   _MSG="ERROR : The property _METRICS_DBNAME must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_DBNAME."
   _RC=11
   displayMsgAndExit
fi

# Test the metrics DB name for uppercase characters
_CHARACTERS=$(echo ${_METRICS_DBNAME} | grep [ABCDEFGHIJKLMNOPQRSTUVWXYZ])
_RC=$?

# _RC = 0 means an uppercase character was found
if [ ${_RC} -eq 0 ] ; then
   _MSG="ERROR:  The metrics DB name ${_METRICS_DBNAME} must not contain uppercase letters."
   displayMsg
   _MSG="ACTION: Ensure the metrics DB name consists only the characters specified in the configure.ini file."
   _RC=11
   displayMsgAndExit
fi

if [ -z "${_METRICS_DBNAME}" ]; then
   _MSG="ERROR : The property _METRICS_DBNAME must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_DBNAME."
   _RC=11
   displayMsgAndExit
fi

if [ -z "${_METRICS_INTERVAL}" ]; then
   _MSG="ERROR : The property _METRICS_INTERVAL must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_INTERVAL."
   _RC=12
   displayMsgAndExit
fi

if [ -z "${_METRICS_USER_ID}" ]; then
   _MSG="ERROR : The property _METRICS_USER_ID must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_USER_ID."
   _RC=8
   displayMsgAndExit
fi

if [ -z "${_METRICS_PASSWORD}" ]; then
   _MSG="ERROR : The property _METRICS_PASSWORD must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _METRICS_PASSWORD."
   _RC=9
   displayMsgAndExit
fi

if [ "${_METRICS_URL}" = "http://localhost:5984" ] ; then
   if [ "${_METRICS_USER_ID}" != "${_ADMIN_USER_ID}" ]; then
      _MSG="ERROR : If _METRICS_URL is http://localhost:5984, the _METRICS_USER_ID must be the same as _ADMIN_USER_ID."
      displayWarning
      _MSG="ACTION: Edit the file configure.ini and set _METRICS_USER_ID the same as _ADMIN_USER_ID."
      _RC=10
      displayMsgAndExit
   fi
   if [ "${_METRICS_PASSWORD}" != "${_ADMIN_PASSWORD}" ]; then
      _MSG="ERROR : If _METRICS_URL is http://localhost:5984, the _METRICS_PASSWORD must be the same as _ADMIN_PASSWORD."
      displayWarning
      _MSG="ACTION: Edit the file configure.ini and set _METRICS_PASSWORD the same as _ADMIN_PASSWORD."
      _RC=11
      displayMsgAndExit
   fi
fi

if [ -z "${_DB_NODE_CNT}" ]; then
   _MSG="ERROR : The property _DB_NODE_CNT must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _DB_NODE_CNT."
   _RC=12
   displayMsgAndExit
fi

if [ -z "${_LB_CNT}" ]; then
   _MSG="ERROR : The property _LB_CNT must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _LB_CNT."
   _RC=20
   displayMsgAndExit
fi

if [ -z "${_COOKIE}" ]; then
   _MSG="ERROR: The property _COOKIE must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _COOKIE."
   _RC=20
   displayMsgAndExit
fi

if [ -z "${_DB_NODE_ARRAY}" ]; then
   _MSG="ERROR: The property _DB_NODE_ARRAY must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _DB_NODE_ARRAY."
   _RC=30
   displayMsgAndExit
fi

if [ -z "${_DB_IP_ARRAY}" ]; then
   _MSG="ERROR: The property _DB_IP_ARRAY must have a value."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _DB_IP_ARRAY."
   _RC=31
   displayMsgAndExit
fi

if [ ${#_DB_NODE_ARRAY[@]} != ${_DB_NODE_CNT} ]; then
   _MSG="ERROR: The value for _DB_NODE_CNT must equal the number of entries in _DB_NODE_ARRAY."
   displayWarning
   _MSG="ACTION: Edit the file configure.ini and set _DB_NODE_CNT and _DB_NODE_ARRAY."
   _RC=32
   displayMsgAndExit
fi

if [ ${_DB_NODE_CNT} -eq 1 ]; then
   _INSTALL_TYPE="s"
   if [ ${_LB_CNT} -ne 0 ]; then
      _MSG="ERROR: If the value for _DB_NODE_CNT is 1, then _LB_CNT must be 0."
      displayWarning
      _MSG="ACTION: Edit the file configure.ini and correct _DB_NODE_CNT and _LB_CNT."
      _RC=33
      displayMsgAndExit
   fi
   # This is a single node install
   _THIS_NODE="sn"
else
   _INSTALL_TYPE="m"
   # if [ ${_LB_CNT} -ne 1 -a ${_LB_CNT} -ne 2 ]; then
   #    _MSG="ERROR: The value for _LB_CNT must be 1 or 2 and equal the number of entries in _LB_ARRAY."
   #    displayWarning
   #    _MSG="ACTION: Edit the file configure.ini and correct _LB_CNT and _LB_ARRAY."
   #    _RC=34
   #    displayMsgAndExit
   #    if [ ${#_LB_ARRAY[@]} != ${_LB_CNT} ]; then
   #       _MSG="ERROR: The value for _LB_CNT must equal the number of entries in _LB_ARRAY."
   #       displayWarning
   #       _MSG="ACTION: Edit the file configure.ini and set _LB_CNT and _LB_ARRAY."
   #       _RC=35
   #       displayMsgAndExit
   #    fi
   # fi
fi

if [ -z "${_THIS_PC}" ]; then
   _MSG="ERROR:  Unable to determine host name."
   displayMsg
   _MSG="ACTION: Ensure that 'hostname -f' returns the correct value for this computer."
   _RC=36
   displayMsgAndExit
fi

# Starting with the first entry (0), ensure that a non default node name was specified
for (( i = 0 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
   if grep -q "your_locale.your_company.com" <<< "${_DB_NODE_ARRAY[$i]}" ; then
      _MSG="ERROR:  A non default computer name must be specified for entry $i in _DB_NODE_ARRAY."
      displayMsg
      _MSG="ACTION: Ensure that '.your_locale.your_company.com' is not specified as part of a computer name in _DB_NODE_ARRAY."
      _RC=37
      displayMsgAndExit
   fi
done

# Starting with the first entry (0), ensure that a non default IP address was specified
for (( i = 0 ; i < ${#_DB_IP_ARRAY[@]} ; i++ )) do
   if [ "${_DB_IP_ARRAY[$i]}" == "0.0.0.0" ]; then
      _MSG="ERROR:  A non default IP address must be specified for entry $i in _DB_IP_ARRAY."
      displayMsg
      _MSG="ACTION: Ensure that '0.0.0.0' is not specified as an IP address in _DB_IP_ARRAY."
      _RC=38
      displayMsgAndExit
   fi
done

# Starting with the first entry (0), ensure that a non default LB name was specified
for (( i = 0 ; i < ${#_LB_ARRAY[@]} ; i++ )) do
   if grep -q "your_locale.your_company.com" <<< "${_LB_ARRAY[$i]}" ; then
      _MSG="ERROR:  A non default computer name must be specified for entry $i in _LB_ARRAY."
      displayMsg
      _MSG="ACTION: Ensure that '.your_locale.your_company.com' is not specified as part of a computer name in _LB_ARRAY."
      _RC=39
      displayMsgAndExit
   fi
done

_MSG="Determining if this computer is in _DB_NODE_ARRAY..."
displayMsg
if [ "${_THIS_PC}" == "${_DB_NODE_ARRAY[0]}" ]; then
   # If this is not a single node implementation, then it is the first DB node
   if [ "${_THIS_NODE}" != "sn" ]; then
      _THIS_NODE=d1   
      _MSG="This computer is the first DB node."
      displayMsg
   fi
else
   # Starting with the second node (1), determine if this node is in the DB list
   for (( i = 1 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
      if [ "${_THIS_PC}" == "${_DB_NODE_ARRAY[$i]}" ]; then
         # This is a general DB node
         _THIS_NODE=db
         echo "This computer is node: $i in _DB_NODE_ARRAY."
         displayMsg
      fi
   done
   # If this is not a DB node, check if it is an LB machine
   if [ "${_THIS_NODE}" != "db" ]; then
      _MSG="Determining if this computer is in _LB_ARRAY..."
      displayMsg
      if [ ${_LB_CNT} -gt 0 -a "${_THIS_PC}" == "${_LB_ARRAY[0]}" ]; then
         _THIS_NODE=l1
         echo "This computer is LB1: (0 in _LB_ARRAY)."
         displayMsg
      elif [ ${_LB_CNT} -eq 2 -a "${_THIS_PC}" == "${_LB_ARRAY[1]}" ]; then
         _THIS_NODE=l2
         echo "This computer is LB2: (1 in _LB_ARRAY)."
         displayMsg
      fi
   fi
fi
if [ "${_THIS_NODE}" != "sn" ] && [ "${_THIS_NODE}" != "d1" ] && [ "${_THIS_NODE}" != "db" ] &&
   [ "${_THIS_NODE}" != "l1" ] && [ "${_THIS_NODE}" != "l2" ]; then
   _MSG="ERROR: This computer ${_THIS_PC} was not found in _DB_NODE_ARRAY or _LB_ARRAY."
   displayMsg
   _MSG="       Ensure _DB_NODE_ARRAY and _LB_ARRAY in $_DIR/configure.ini are correct."
   displayMsg
   _MSG="       Ensure _DB_NODE_CNT and _LB_CNT in $_DIR/configure.ini are correct."
   displayMsg
   _MSG="       Ensure the value in /etc/hostname is correct"
   if [ "${_OS}" == "Linux" ]; then
      if [ "${_DISTRO}" == "CentOS" -o "${_DISTRO}" == "RedHat" -o "${_DISTRO}" == "RedHat variant" ]; then
      _MSG="       and agrees with the value in /etc/sysconfig/network."
      elif [ "${_DISTRO}" == "Debian" -o "${_DISTRO}" == "Ubuntu" -o "${_DISTRO}" == "Debian variant" ]; then
      _MSG="       and agrees with the value in /etc/hostname."
      fi
   fi
   displayMsg
   _MSG="       And 'hostname -f' returns a value contained _DB_NODE_ARRAY or _LB_ARRAY."
   _RC=50
   displayMsgAndExit
fi
if [ "${_DELETE_DB}" == "y" ]; then
   if [ "${_THIS_NODE}" == "l1" -o "${_THIS_NODE}" == "l2" ]; then
      _MSG="ERROR: -D is only valid for a database or single node machine."
      _RC=51
      displayMsgAndExit
   fi
fi

# If this is the second or subsequent node, ensure an encrypted password is present
if [ "${_THIS_NODE}" == "db" ]; then
   if [ "${_ADMIN_ENCRYPTED_PASSWORD}" = "_admin_not_set" ]; then
      _MSG="ERROR : The property _ADMIN_ENCRYPTED_PASSWORD must have an encrypted value."
      displayWarning
      _MSG="ACTION: Run the configure.sh on the first node to set the encrypted value."
      displayWarning
      _MSG="        Then run copy the updated configure.ini file to this node and run configure.sh again."
      displayWarning
      _RC=52
      displayMsgAndExit
   fi

   if [ "${_CLOUDANT_ENCRYPTED_PASSWORD}" = "_cloudant_not_set" ]; then
      _MSG="ERROR : The property _CLOUDANT_ENCRYPTED_PASSWORD must have an encrypted value."
      displayWarning
      _MSG="ACTION: Run the configure.sh on the first node to set the encrypted value."
      displayWarning
      _MSG="        Then run copy the updated configure.ini file to this node and run configure.sh again."
      displayWarning
      _RC=53
      displayMsgAndExit
   fi
fi

_FUNCTION="N/A"
_POS=$LINENO
displayDebug

# Determine if this is a existing installation and a cookie was previously set
if [ -f /opt/cloudant/etc/vm.args ] ; then
   _MSG="Inspecting the file /opt/cloudant/etc/vm.args ..."
   displayMsg
   # Determine of a cookie has already been added
   $(grep -q monster /opt/cloudant/etc/vm.args)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _MSG="Reading existing cookie value from /opt/cloudant/etc/vm.args ...."
      displayMsg
      _STRING=$(grep "-setcookie " /opt/cloudant/etc/vm.args)
      _RC=$?
      # _RC=0 means it found a match
      if [ ${_RC} -eq 0 ]; then
         _TOKENS=( $_STRING )
         # Ensure the token is not blank
         if [ ! -z ${_TOKENS[1]} ] ; then
            _MSG="Obtaining existing cookie..."
            displayMsg
            # Determine if this is the first DB node or a SN
            if [ ${_THIS_NODE} = "d1" -o ${_THIS_NODE} = "sn" ]; then
               _COOKIE=${_TOKENS[1]}
            elif [ "${_CFG_COOKIE}" != "${_COOKIE}" ] ; then
               _MSG="The value for _COOKIE in the configure.ini file, does not match the value in vm.args."
               displayMsg
               _MSG="${_DIR}/configure.ini has ${_CFG_COOKIE}"
               displayMsg
               _MSG="/opt/cloudant/etc/vm.args has ${_COOKIE}"
               displayMsg            
               _MSG="You must ensure that the value for _COOKIE in the configure.ini file, matched the value in vm.args."
               _RC=54
               displayMsgAndExit
            fi
         fi
      fi

      # If 'monster' is not in the vm.args file it means a cookie was previously set
      # Ensure that the same cookie is in erl_call_cloudant
      # Determine if the erl_call_cloudant file exists
      if [ -f /opt/cloudant/bin/erl_call_cloudant ] ; then
         _MSG="Configuring the file /opt/cloudant/bin/erl_call_cloudant ..."
         displayMsg
         sed -i "s/-c monster/-c ${_COOKIE}/gi" /opt/cloudant/bin/erl_call_cloudant
      fi
   fi
fi

_FUNCTION="N/A"
_POS=$LINENO
displayDebug

_MSG="-------------------------------------------------------------------------"
displayMsg
_MSG="Configuring Cloudant Local with the following values:"
displayMsg
_MSG="_THIS_COMPUTER              : ${_THIS_PC}"
displayMsg
_MSG="_ADMIN_USER_ID              : ${_ADMIN_USER_ID}"
displayMsg
_MSG="_ADMIN_PASSWORD             : ********"
#_MSG="_ADMIN_PASSWORD             : ${_ADMIN_PASSWORD}"
displayMsg
_MSG="_ADMIN_ENCRYPTED_PASSWORD   : ${_ADMIN_ENCRYPTED_PASSWORD}"
displayMsg
_MSG="_CLOUDANT_PASSWORD          : ********"
#_MSG="_CLOUDANT_PASSWORD          : ${_CLOUDANT_PASSWORD}"
displayMsg
_MSG="_CLOUDANT_ENCRYPTED_PASSWORD: ${_CLOUDANT_ENCRYPTED_PASSWORD}"
displayMsg
_MSG="_HAPROXY_USER_ID            : ${_HAPROXY_USER_ID}"
displayMsg
_MSG="_HAPROXY_PASSWORD           : ********"
#_MSG="_HAPROXY_PASSWORD           : ${_HAPROXY_PASSWORD}"
displayMsg
_MSG="_JMXREMOTE_PASSWORD         : ********"
#_MSG="_JMXREMOTE_PASSWORD         : ${_JMXREMOTE_PASSWORD}"
displayMsg
_MSG="_METRICS_URL                : ${_METRICS_URL}"
displayMsg
_MSG="_METRICS_DBNAME             : ${_METRICS_DBNAME}"
displayMsg
_MSG="_METRICS_INTERVAL           : ${_METRICS_INTERVAL}"
displayMsg
_MSG="_METRICS_USER_ID            : ${_METRICS_USER_ID}"
displayMsg
_MSG="_METRICS_PASSWORD           : ********"
_MSG="Start in _MAINT_MODE        : ${_MAINT_MODE}"
displayMsg
_MSG="DB Nodes:"
displayMsg
_MSG=" _DB_NODE_CNT               : ${_DB_NODE_CNT}"
displayMsg
for (( i = 0 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
   _MSG=" _DB_NODE_ARRAY[$i] : ${_DB_NODE_ARRAY[$i]}  ${_DB_IP_ARRAY[$i]}"
   displayMsg
done
_MSG="LB Nodes:"
displayMsg
_MSG=" _LB_CNT                    : ${_LB_CNT}"
displayMsg
if [ ${_LB_CNT} -gt 0 ]; then
   for (( l = 0 ; l < ${#_LB_ARRAY[@]} ; l++ )) do
      _MSG=" _LB_ARRAY[$l]              : ${_LB_ARRAY[$l]}"
      displayMsg
   done
fi
_MSG="_THIS_NODE                  : ${_THIS_NODE}"
displayMsg
_MSG="_INSTALL_TYPE               : ${_INSTALL_TYPE}"
displayMsg
_MSG="_COOKIE                     : ${_COOKIE}"
displayMsg
if [ "${_DELETE_DB}" == "y" ]; then
   _MSG="**************************************************************"
   displayMsg
   _MSG="WARNING: -D specified, the cloudant Databases will be deleted!"
   displayMsg
   _MSG="**************************************************************"
   displayMsg
fi
# Only display this prompt in verbose mode
if [ "${_VERBOSE}" == "y" ]; then
   read -p "Is this correct? (y/n):" -n 1 -r
   if [[ $REPLY =~ ^[Yy]$ ]]; then
      _MSG=" "
      displayMsg
   else
      _MSG=" "
      displayMsg
      _MSG="Canceled by user. Verify the configure.ini has the correct property values before running."
      _RC=60
      displayMsgAndExit
   fi
fi

# Ensure a node was specified
_MSG="--------------------------------------------------------------"
displayMsg
if [ "${_INSTALL_TYPE}" == "m" ]; then
   _MSG="Configuring Cloudant Local with ${_DB_NODE_CNT} DB nodes."
   displayMsg
   _MSG="--------------------------------------------------------------"
   displayMsg
   if [ ${_LB_CNT} -eq 1 ]; then
      _MSG="Configuring Cloudant Local with 1 LB machine."
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
   elif [ ${_LB_CNT} -eq 2 ]; then
      _MSG="Configuring Cloudant Local with 2 LB machines."
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
   # else
   #    _MSG="INTERNAL ERROR: _INSTALL_TYPE is m (multi-node) but _LB_CNT is not 1 or 2."
   #    _RC=71
   #    displayMsgAndExit
   fi
elif [ "${_INSTALL_TYPE}" == "s" ]; then
   _MSG="Configuring a single node implementation of Cloudant Local."
   displayMsg
   _MSG="--------------------------------------------------------------"
   displayMsg
   if [ ${_LB_CNT} -ne 0 ]; then
      _MSG="INTERNAL ERROR: _INSTALL_TYPE is s (single-node) but _LB_CNT is not 0."
      _RC=72
      displayMsgAndExit
   fi
else
   _MSG="INTERNAL ERROR: _INSTALL_TYPE must be m (multi-node) or s (single node)."
   _RC=73
   displayMsgAndExit
fi

if [ ${_DELAYED_IGNORE_ERRORS} -eq 1 ] ; then
   _IGNORE_ERRORS=1
fi

# Determine if this is a existing installation and a cookie was previously set
if [ -f /opt/cloudant/etc/vm.args ] ; then
   _MSG="Inspecting the file /opt/cloudant/etc/vm.args ..."
   displayMsg
   # Determine of a cookie has already been added
   $(grep -q monster /opt/cloudant/etc/vm.args)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      # If 'monster' is not in the vm.args file it means a cookie was previously set
      # Ensure that the same cookie is in erl_call_cloudant
      # Determine if the erl_call_cloudant file exists
      if [ -f /opt/cloudant/bin/erl_call_cloudant ] ; then
         _MSG="Configuring the file /opt/cloudant/bin/erl_call_cloudant ..."
         displayMsg
         sed -i "s/-c monster/-c ${_COOKIE}/gi" /opt/cloudant/bin/erl_call_cloudant
      fi
   fi
fi

# Put cloudant into maintenance mode
${_DIR}/cloudant.sh -m
# Wait 10 seconds to clear the queue
sleep 10
# Stop Cloudant
${_DIR}/cloudant.sh -k

if [ "${_DELETE_DB}" == "y" ]; then
   _MSG="Deleting the Cloudant Database on this machine ..."
   displayMsg
   rm -rf /srv/cloudant/{db,view_index,search_index,geo_index}
fi

# Determine if the metrics.ini file exists
if [ -f /opt/cloudant/etc/metrics.ini ] ; then
   _MSG="Configuring the file /opt/cloudant/etc/metrics.ini ...."
   displayMsg
   # Assign the user ID to the admin USER_ID (new format)
   sed -i "1,4s/USERID: *admin$/USERID: ${_ADMIN_USER_ID} /1" /opt/cloudant/etc/metrics.ini
   # Assign the password to the admin password (new format)
   sed -i "1,4s/PASSWORD: *password$/PASSWORD: ${_ADMIN_PASSWORD} /1" /opt/cloudant/etc/metrics.ini
   # Assign the metrics url 
   sed -i "s~URL: *http://localhost:5984 ~URL: ${_METRICS_URL} ~" /opt/cloudant/etc/metrics.ini
   # Assign the metrics DB Name
   sed -i "s~METRICS_DBNAME: *metrics ~METRICS_DBNAME: ${_METRICS_DBNAME} ~1" /opt/cloudant/etc/metrics.ini
   # Assign the metrics Interval
   sed -i "s~METRICS_INTERVAL: *1 ~METRICS_INTERVAL: ${_METRICS_INTERVAL} ~g" /opt/cloudant/etc/metrics.ini
   # Assign the user ID to the Metrics USER_ID)
   sed -i "5,16s/USERID: *admin$/USERID: ${_METRICS_USER_ID} /1" /opt/cloudant/etc/metrics.ini
   # Assign the password to the Metrics password
   sed -i "5,16s/PASSWORD: *password$/PASSWORD: ${_METRICS_PASSWORD} /1" /opt/cloudant/etc/metrics.ini

else
   _MSG="*** The file /opt/cloudant/etc/metrics.ini not found.  Skipping. ***"
   displayMsg
fi

# Determine if the local.ini file exists
if [ -f /opt/cloudant/etc/local.ini ] ; then

   _MSG="--------------------------------------------------------------"
   displayMsg
   _MSG="Configuring the file /opt/cloudant/etc/local.ini ...."
   displayMsg
   # Determine if an [admins] section exists
   $(grep -q admins /opt/cloudant/etc/local.ini)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      # Determine if this is the first DB node or a SN
      if [ ${_THIS_NODE} = "d1" -o ${_THIS_NODE} = "sn" ]; then
         # Add the [admins] section to the file
         echo " " >> /opt/cloudant/etc/local.ini
         echo "[admins]" >> /opt/cloudant/etc/local.ini

         # If an encrypted password from a previous run was saved used it
         if [ "${_ADMIN_ENCRYPTED_PASSWORD}" = "_admin_not_set" ]; then
            _MSG="Writing the unencrypted admin password to the file /opt/cloudant/etc/local.ini ...."
            displayMsg
            echo "${_ADMIN_USER_ID} = ${_ADMIN_PASSWORD}" >> /opt/cloudant/etc/local.ini
         else
            _MSG="Writing the encrypted admin password to the file /opt/cloudant/etc/local.ini ...."
            displayMsg
            echo "${_ADMIN_USER_ID} = ${_ADMIN_ENCRYPTED_PASSWORD}" >> /opt/cloudant/etc/local.ini
         fi

         # If an encrypted password from a previous run was saved used it
         if [ "${_CLOUDANT_ENCRYPTED_PASSWORD}" = "_cloudant_not_set" ]; then
            _MSG="Writing the unencrypted cloudant password to the file /opt/cloudant/etc/local.ini ...."
            displayMsg
            echo "cloudant = ${_CLOUDANT_PASSWORD}" >> /opt/cloudant/etc/local.ini
         else
            _MSG="Writing the encrypted cloudant password to the file /opt/cloudant/etc/local.ini ...."
            displayMsg
            echo "cloudant = ${_CLOUDANT_ENCRYPTED_PASSWORD}" >> /opt/cloudant/etc/local.ini
         fi

      elif [ ${_THIS_NODE} = "db" ] ; then
         # Add the [admins] section to the file
         echo " " >> /opt/cloudant/etc/local.ini
         echo "[admins]" >> /opt/cloudant/etc/local.ini
         echo "${_ADMIN_USER_ID} = ${_ADMIN_ENCRYPTED_PASSWORD}" >> /opt/cloudant/etc/local.ini
         echo "cloudant = ${_CLOUDANT_ENCRYPTED_PASSWORD}" >> /opt/cloudant/etc/local.ini
      fi
   fi
else
   _MSG="*** The file /opt/cloudant/etc/local.ini not found.  Skipping. ***"
   displayMsg
fi

# Determine if this is a single-node implementation
if [ "${_INSTALL_TYPE}" = "s" ]; then
   # Determine if the default.ini file exists
   if [ -f /opt/cloudant/etc/default.ini ] ; then
      _MSG="Configuring the file /opt/cloudant/etc/default.ini ...."
      displayMsg
      sed -i 's/r=2/r=1/gi' /opt/cloudant/etc/default.ini
      sed -i 's/w=2/w=1/gi' /opt/cloudant/etc/default.ini
      sed -i 's/n=3/n=1/gi' /opt/cloudant/etc/default.ini
   fi
fi

# Determine if the configure.ini file exists
if [ -f $_DIR/configure.ini ] ; then
   _MSG="Configuring the file $_DIR/configure.ini ..."
   displayMsg
   _TOKEN1=' _COOKIE=$(openssl rand -hex 16)'
   _TOKEN2=' _COOKIE=$(openssl KEEP -hex 16)'
   _TOKEN3='_COOKIE=$(openssl rand -hex 16)'
   # "Backup" the comment
   sed -i "s/${_TOKEN1}/${_TOKEN2}/gi" $_DIR/configure.ini
   # "Replace" the actual cookie
   sed -i "s/${_CFG_COOKIE}/${_COOKIE}/gi" $_DIR/configure.ini
   # "Replace" the actual cookie
   sed -i "s/${_TOKEN3}/_COOKIE=${_COOKIE}/gi" $_DIR/configure.ini
   # "Restore" the comment
   sed -i "s/${_TOKEN2}/${_TOKEN1}/gi" $_DIR/configure.ini
fi

# Determine if the vm.args file exists
if [ -f /opt/cloudant/etc/vm.args ] ; then
   _MSG="Configuring the file /opt/cloudant/etc/vm.args ..."
   displayMsg
   # Determine of the entry has already been added
   $(grep -q "${_THIS_PC}" /opt/cloudant/etc/vm.args)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      sed -i "s/-name cloudant@/-name cloudant@${_THIS_PC} #/gi" /opt/cloudant/etc/vm.args
   fi

   sed -i "s/-setcookie monster/-setcookie ${_COOKIE} /gi" /opt/cloudant/etc/vm.args
fi

# Determine if the clouseau.ini file exists
if [ -f /opt/cloudant/etc/clouseau.ini ] ; then
   _MSG="Configuring the file /opt/cloudant/etc/clouseau.ini ..."
   displayMsg
   sed -i "s/cookie=monster/cookie=${_COOKIE}/gi" /opt/cloudant/etc/clouseau.ini
fi

# Determine if the remsh file exists
if [ -f /opt/cloudant/bin/remsh ] ; then
   _MSG="Configuring the file /opt/cloudant/bin/remsh ..."
   displayMsg
   sed -i "s/-setcookie monster/-setcookie ${_COOKIE}/gi" /opt/cloudant/bin/remsh
fi

# Determine if the erl_call_cloudant file exists
if [ -f /opt/cloudant/bin/erl_call_cloudant ] ; then
   _MSG="Configuring the file /opt/cloudant/bin/erl_call_cloudant ..."
   displayMsg
   sed -i "s/-c monster/-c ${_COOKIE}/gi" /opt/cloudant/bin/erl_call_cloudant
fi

# Determine if the jmxremote.password file exists
if [ -f /opt/cloudant/etc/jmxremote.password ] ; then
   _MSG="--------------------------------------------------------------"
   displayMsg
   _MSG="Configuring the file /opt/cloudant/etc/jmxremote.password ...."
   displayMsg

   # Flag to indicate if the file should be updated
   _UPDATE=0
   # Determine if an monitorRole section exists
   $(grep -q monitorRole /opt/cloudant/etc/jmxremote.password)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _UPDATE=1
   fi
   # Determine if an ${_JMXREMOTE_PASSWORD} section exists
   $(grep -q ${_JMXREMOTE_PASSWORD} /opt/cloudant/etc/jmxremote.password)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _UPDATE=1
   fi

   # if the entry "monitorRole ${_JMXREMOTE_PASSWORD}" already exist, no need to update
   if [ ${_UPDATE} -eq 1 ] ; then
      # Determine if the jmxremote.password file exists
      if [ -f /opt/cloudant/etc/jmxremote.password ] ; then
         if [ -f /opt/cloudant/etc/jmxremote.password.old ] ; then
            # Unconditionally remove the file
            rm -f /opt/cloudant/etc/jmxremote.password.old
         fi
         # Unconditionally rename the file
         mv /opt/cloudant/etc/jmxremote.password /opt/cloudant/etc/jmxremote.password.old
      fi
      # Add the monitorRole section to the file
      echo "monitorRole ${_JMXREMOTE_PASSWORD}" >> /opt/cloudant/etc/jmxremote.password
   fi
   # FB 44247 Ensure the file is owned by cloudant
   chown cloudant:cloudant /opt/cloudant/etc/jmxremote.password
   chmod 600 /opt/cloudant/etc/jmxremote.password
else
   _MSG="*** The file /opt/cloudant/etc/jmxremote.password not found.  Skipping. ***"
   displayMsg
fi

# Determine if the haproxy.cfg file exists
if [ -f /etc/haproxy/haproxy.cfg ] ; then
   _MSG="Configuring the file /etc/haproxy/haproxy.cfg ..."
   displayMsg

   # Determine if the bind *.80 has been commented out
   $(grep -q " #bind \*:80" /etc/haproxy/haproxy.cfg)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _MSG="   Commenting out bind *:80 ..."
      displayMsg
      # Comment out the existing bind entry
      sed -i "s/ bind \*:80/ #bind \*:80/gi" /etc/haproxy/haproxy.cfg
   fi

   _LOG_INFO="log 127.0.0.1 local2"
   _LOG_WARNING="log 127.0.0.1 local4 warning"
   _LOG_DEBUG="log 127.0.0.1 local4 debug"

   # Determine of the log setting has been set to warning
   $(grep -q "${_LOG_WARNING}" /etc/haproxy/haproxy.cfg)
   _RC_W=$?
   # Determine of the log setting has been set to debug
   $(grep -q "${_LOG_DEBUG}" /etc/haproxy/haproxy.cfg)
   _RC_D=$?
   # _RC=0 means it found a match
   # Ensure neither warning or debug has already been set
   if [ ${_RC_W} -ne 0 -a ${_RC_D} -ne 0 ]; then
      sed -i "s/${_LOG_INFO}/${_LOG_WARNING}/gi" /etc/haproxy/haproxy.cfg
   fi

   # Assign the user ID and password
   sed -i "s/stats auth admin:admin/stats auth ${_HAPROXY_USER_ID}:${_HAPROXY_PASSWORD}/gi" /etc/haproxy/haproxy.cfg

   # Comment out the existing server entries
   sed -i "s/  server db1.domain.com/  #server db1.domain.com/gi" /etc/haproxy/haproxy.cfg
   sed -i "s/  server db2.domain.com/  #server db2.domain.com/gi" /etc/haproxy/haproxy.cfg
   sed -i "s/  server db3.domain.com/  #server db2.domain.com/gi" /etc/haproxy/haproxy.cfg

   _SERVER_FOUND=y
   # Determine if any entries have already been written
   for (( i = 0 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
      # Determine if then node has been added
      $(grep -q ${_DB_NODE_ARRAY[$i]} /etc/haproxy/haproxy.cfg)
      _RC=$?
      # _RC=0 means it found a match
      if [ ${_RC} -ne 0 ]; then
         _SERVER_FOUND=n
      fi
   done

   # Determine if at least 1 entry needs to be added
   if [ "${_SERVER_FOUND}" == "n" ] ; then
      # Comment out the existing backend section
      # ( The string "backend dashboard_assets_host" is used in two locations.. we only want to comment the second instance)
      sed -i "s/use_backend dashboard_assets_host if dashboard_assets/use_backendXdashboard_assets_host if dashboard_assets/gi" /etc/haproxy/haproxy.cfg
      sed -i "s/backend dashboard_assets_host/  #backend dashboard_assets_host/gi" /etc/haproxy/haproxy.cfg
      sed -i "s/use_backendXdashboard_assets_host if dashboard_assets/use_backend dashboard_assets_host if dashboard_assets/gi" /etc/haproxy/haproxy.cfg
      # ( Use ~ instead of / since string contains a / )
      sed -i "s~  option httpchk GET /dashboard.html~    #option httpchk GET /dashboard.html~gi" /etc/haproxy/haproxy.cfg
      sed -i "s/  server localhost 127.0.0.1:5656 check inter 7s/    #server localhost 127.0.0.1:5656 check inter 7s/gi" /etc/haproxy/haproxy.cfg

      # Add new servers to the bottom of the file
      echo "  ###### " >> /etc/haproxy/haproxy.cfg
      echo "  # NOTE: Specify the appropriate host names and IP addresses below. " >> /etc/haproxy/haproxy.cfg
      echo "  ###### " >> /etc/haproxy/haproxy.cfg

      # Determine if these entries have already been written
      for (( i = 0 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
         # Determine if then node has been added
         $(grep -q ${_DB_NODE_ARRAY[$i]} /etc/haproxy/haproxy.cfg)
         _RC=$?
         # _RC=0 means it found a match
         if [ ${_RC} -ne 0 ]; then
            echo "  server ${_DB_NODE_ARRAY[$i]} ${_DB_IP_ARRAY[$i]}:5984 check inter 7s" >> /etc/haproxy/haproxy.cfg
         fi
      done

      # Add a new backend section
      echo " " >> /etc/haproxy/haproxy.cfg
      echo "backend dashboard_assets_host" >> /etc/haproxy/haproxy.cfg
      echo "  option httpchk GET /dashboard.html" >> /etc/haproxy/haproxy.cfg
      echo "  server localhost 127.0.0.1:5656 check inter 7s" >> /etc/haproxy/haproxy.cfg
   fi
fi

# Determine if the rsyslog.conf file exists
if [ -f /etc/rsyslog.conf ] ; then
   _MSG="Configuring the file /etc/rsyslog.conf ..."
   displayMsg

   # Determine if the $ModLoad imudp setting has been enabled
   sed -i "s/#\$ModLoad imudp/\$ModLoad imudp/gi" /etc/rsyslog.conf

   # Ensure the ModLoad imudp entry has been included
   $(grep -q "ModLoad imudp" /etc/rsyslog.conf)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _MSG="   Adding $ModLoad imudp ..."
      displayMsg
      echo "#### MODULES ####" >> /etc/rsyslog.conf
      echo "$ModLoad imudp" >> /etc/rsyslog.conf
   fi

   # Determine if the $ModLoad imudp setting has been enabled
   sed -i "s/#\$UDPServerRun 514/\$UDPServerRun 514/gi" /etc/rsyslog.conf

   # Ensure the ModLoad imudp entry has been included
   $(grep -q "UDPServerRun 514" /etc/rsyslog.conf)
   _RC=$?
   # _RC=0 means it found a match
   if [ ${_RC} -ne 0 ]; then
      _MSG="   Adding $UDPServerRun 514 ..."
      displayMsg
      echo "$UDPServerRun 514" >> /etc/rsyslog.conf
   fi
fi

# Determine if the ryslog.d directory exists
if [ -d /etc/rsyslog.d ] ; then

   # Determine if this is a DB or SN
   if [ ${_THIS_NODE} = "d1" -o ${_THIS_NODE} = "db" -o ${_THIS_NODE} = "sn" ]; then
      _MSG="Configuring the file /etc/rsyslog.d/cloudant.conf ..."
      displayMsg

      # Determine if the cloudant.conf file exists
      if [ -f /etc/rsyslog.d/cloudant.conf ] ; then
         if [ -f /etc/rsyslog.d/cloudant.conf.old ] ; then
            # Unconditionally remove the file
            rm -f /etc/rsyslog.d/cloudant.conf.old
         fi
         # Unconditionally rename the file
         mv /etc/rsyslog.d/cloudant.conf /etc/rsyslog.d/cloudant.conf.old
      fi

      # Add the local logging section to the file
      # FB 44247 Add a & ~ to each line to remove duplicate looging of messages
      echo "local2.*   /var/log/cloudant/cloudant.log" >> /etc/rsyslog.d/cloudant.conf
      echo "& ~"                                       >> /etc/rsyslog.d/cloudant.conf
      echo "local5.*   /var/log/cloudant/clouseau.log" >> /etc/rsyslog.d/cloudant.conf
      echo "& ~"                                       >> /etc/rsyslog.d/cloudant.conf
      echo "local3.*   /var/log/cloudant/metrics.log"  >> /etc/rsyslog.d/cloudant.conf
      echo "& ~"                                       >> /etc/rsyslog.d/cloudant.conf
   fi

   # Determine if this is a LB or SN
   if [ ${_THIS_NODE} = "l1" -o ${_THIS_NODE} = "l2" -o ${_THIS_NODE} = "sn" ]; then
      _MSG="Configuring the file /etc/rsyslog.d/haproxy.conf ..."
      displayMsg

      # Determine if the rsyslog.d/haproxy.conf file exists
      if [ -f /etc/rsyslog.d/haproxy.conf ] ; then
         if [ -f /etc/rsyslog.d/haproxy.conf.old ] ; then
            # Unconditionally remove the file
            rm -f /etc/rsyslog.d/haproxy.conf.old
         fi

         # Unconditionally rename the file
         mv /etc/rsyslog.d/haproxy.conf /etc/rsyslog.d/haproxy.conf.old
      fi

      # Specify what messages to collect and where the log file is located
      # FB 44247 Add a & ~ to each line to remove duplicate looging of messages
      echo "local4.*     /var/log/haproxy.log" >> /etc/rsyslog.d/haproxy.conf
      echo "& ~"                               >> /etc/rsyslog.d/haproxy.conf
   fi
fi

# Determine if this is a load balancer node
if [ ${_THIS_NODE} = "l1" -o ${_THIS_NODE} = "l2" ]; then
   if [ ${_LB_CNT} -gt 1 ]; then
      _PKG_NAME=keepalived

      _MSG="${_LB_CNT} Load Balancers detected ..."
      displayMsg

      _MSG="Preparing to configure ${_PKG_NAME} ..."
      displayMsg

      # Ensure that the OS is supported
      if [ "$_OS" = "Linux" ]; then
         # Ensure that the Linux distribution is supported
         if [ "$_DISTRO" = "CentOS" -o "$_DISTRO" = "RedHat" -o "$_DISTRO" = "RedHat variant" ]; then
            # Determine if keepalived is installed
            _state=`rpm -qa | grep ${_PKG_NAME}`
            if [ -z "$_state" ]; then 
               _MSG="Installing ${_PKG_NAME} ..."
               displayMsg
               yum ${_QUIET} install ${_PKG_NAME}
               _RC=$?
               if [[ ${_RC} != 0 ]] ; then
                  _MSG="Install for ${_PKG_NAME} failed or was canceled by user."
                  _CMD="yum ${_QUIET} install ${_PKG_NAME}"
                  _PKG="${_PKG_NAME}"
                  displayFailureAndExit
               fi
            fi
         elif [ "$_DISTRO" = "Debian" -o "$_DISTRO" = "Ubuntu" -o  "$_DISTRO" = "Debian variant" ]; then
            # Determine if keepalived is installed
            dpkg -l ${_PKG_NAME} > /dev/null 2>&1
            _STATE=$?   
            if [ $_STATE == '1' ]; then
               _MSG="Installing ${_PKG_NAME} ..."
               displayMsg
               apt-get ${_QUIET} install ${_PKG_NAME}
               _RC=$?
               if [[ ${_RC} != 0 ]] ; then
                  _MSG="Install for ${_PKG_NAME} failed or was canceled by user."
                  _CMD="apt-get ${_QUIET} install ${_PKG_NAME}"
                  _PKG="${_PKG_NAME}"
                  displayFailureAndExit
               fi
            fi
         else
            echo "Cloudant is not supported on this Linux distribution."
            exit 3
         fi
         _MSG="Enabling ${_PKG_NAME} ..."
         displayMsg
         chkconfig keepalived on
      else
         echo "Cloudant is not supported on this OS."
         exit 4
      fi
   fi
fi

# Enable Ports
${_DIR}/enableports.sh

# Start Cloudant
${_DIR}/cloudant.sh -s

# Only do the following test for a DB or SN Node
if [ "${_THIS_NODE}" != "l1" -a "${_THIS_NODE}" != "l2" ]; then
   _MSG="Waiting for Cloudant to start ..."
   displayMsg
   _CNT=0
   _STOP_CNT=30
   _URL=http://localhost:5984/_up
   while [ $_CNT -lt $_STOP_CNT ]; do
      let _CNT=_CNT+1
      sleep 1
      _res=$(curl -qSfsw '\n%{http_code}' -X GET ${_URL})  2>/dev/null
      _RC=$?
      # Did Cloudant start normally?
      if [ $_RC -eq 0 ]; then
         let _CNT=_STOP_CNT
         # FBugz 44265 If the user wants to leave Cloudant in maintenance mode, ensure we are in maintenence mode
         # This would happen if we weren't able to put the previouse version in maintenance mode
         if [ ${_MAINT_MODE} -eq 1 ]; then
            # Ensure Cloudant is in maintenance mode
            ${_DIR}/cloudant.sh -m
            let _CNT=_STOP_CNT
         else
            _MSG="Testing the Cloudant password...."
            displayMsg
            # Ensure password is correct
            _res=$(curl -qSfsw '\n%{http_code}' -X GET -u ${_ADMIN_USER_ID}:${_ADMIN_PASSWORD} ${_URL})  2>/dev/null
            _RC=$?
            # Is the node running?
            if [ $_RC -eq 0 ]; then
               _MSG="Password has been validated..."
               displayMsg
            # If an error occured, the password is invalid
            elif [ $_RC -eq 22 ]; then
               _MSG="Unable to validate the user ID and password."
               displayMsg
               _MSG="1) Clear the [admins] section of the /opt/cloudant/etc/local.ini file on each node"
               displayMsg
               _MSG="2) In the ~/Cloudant/repo/configure.ini file, set the these variables as shown here:"
               displayMsg
               _MSG="   _ADMIN_ENCRYPTED_PASSWORD=_admin_not_set"
               displayMsg
               _MSG="   _CLOUDANT_ENCRYPTED_PASSWORD=_cloudant_not_set"
               displayMsg
               _MSG="Then rerun the configure.sh script on all nodes."
               displayMsgAndExit
            fi
         fi
      # Did Cloudant start in maintenance mode?
      elif [ $_RC -eq 22 ]; then
         # FBugz 44265 If the user wants to leave cloudant in maintenance mode, just exit loop
         if [ ${_MAINT_MODE} -eq 1 ]; then
            let _CNT=_STOP_CNT
         else
            # Ensure Cloudant is not in maintenance mode
            ${_DIR}/cloudant.sh -w
         fi
      fi
   done

   if [ ${_MAINT_MODE} -eq 1 ]; then
      _MSG="Cloudant is now in maintenance mode, some checks will be skipped."
      displayMsg
   else
      _MSG=" "
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG="Testing the Cloudant endpoint ${_THIS_PC}:"
      displayMsg
      _MSG="curl -qSfsw '\n%{http_code}' -X GET -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL

      _MSG=" "
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG="The current membership for ${_THIS_PC}:"
      displayMsg
      _URL=http://${_THIS_PC}:5984/_membership
      _MSG="curl -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL

      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG="All databases for ${_DB_NODE_ARRAY[0]}:"
      displayMsg
      _URL=http://${_DB_NODE_ARRAY[0]}:5984/_all_dbs
      _MSG="curl -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL

      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG="Current documents for localhost:"
      displayMsg
      _URL=http://localhost:5986/nodes/_all_docs?include_docs=true
      _MSG="curl -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL

      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG=" "
      displayMsg
   fi
fi

# Only do the following if this is the first DB node or a SN
if [ ${_THIS_NODE} = "d1" -o ${_THIS_NODE} = "sn" ]; then

   # Ensure the local.ini file exists
   if [ -f /opt/cloudant/etc/local.ini ] ; then
      _MSG="--------------------------------------------------------------"
      displayMsg

      # Determine of the encrypted passwords have been set
      if [ "${_ADMIN_ENCRYPTED_PASSWORD}" = "_admin_not_set" ]; then
         _MSG="Reading the encrypted value for admin from the file /opt/cloudant/etc/local.ini ...."
         displayMsg
         _STRING=$(grep "admin =" /opt/cloudant/etc/local.ini)
         _RC=$?
         # _RC=0 means it found a match
         if [ ${_RC} -eq 0 ]; then
            _TOKENS=( $_STRING )
            _ADMIN_ENCRYPTED_PASSWORD=${_TOKENS[2]}
            # Ensure the encrypted password is not blank
            if [ ! -z ${_ADMIN_ENCRYPTED_PASSWORD} ] ; then
               _MSG="Updating the the file $_DIR/configure.ini with the encrypted admin password..."
               displayMsg
               # "Replace" the actual encrypted value
               sed -i "s/_admin_not_set/${_ADMIN_ENCRYPTED_PASSWORD}/gi" $_DIR/configure.ini
            fi
         fi
      fi
      # Determine of the encrypted passwords have been set
      if [ "${_CLOUDANT_ENCRYPTED_PASSWORD}" = "_cloudant_not_set" ]; then
         _MSG="Reading the encrypted value for cloudant from the file /opt/cloudant/etc/local.ini ...."
         displayMsg
         _STRING=$(grep "cloudant =" /opt/cloudant/etc/local.ini)
         _RC=$?
         # _RC=0 means it found a match
         if [ ${_RC} -eq 0 ]; then
            _TOKENS=( $_STRING )
            _CLOUDANT_ENCRYPTED_PASSWORD=${_TOKENS[2]}
            # Ensure the encrypted password is not blank
            if [ ! -z ${_CLOUDANT_ENCRYPTED_PASSWORD} ] ; then
               _MSG="Updating the the file $_DIR/configure.ini with the encrypted cloudant password..."
               displayMsg
               # "Replace" the actual encrypted value
               sed -i "s/_cloudant_not_set/${_CLOUDANT_ENCRYPTED_PASSWORD}/gi" $_DIR/configure.ini
            fi
         fi
      fi
   fi
fi

if [ ${_MAINT_MODE} -eq 1 ]; then
   _MSG="Run ${_DIR}/configure.sh with out the -m option to complete the configuration."
   displayMsgAndExit
fi

# Determine if this is a multi-node configuration
if [ "${_INSTALL_TYPE}" = "m" ]; then

   # Only do the following if this is NOT a LB only mode
   if [ "${_THIS_NODE}" != "l1" -a "${_THIS_NODE}" != "l2" ]; then
      _MSG=" "
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg

      # Starting with the first node (0), Display the status of each node
      for (( i = 0 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
         _MSG="Testing the status for ${_DB_NODE_ARRAY[$i]}"
         displayMsg
         _MSG="curl -u ${_ADMIN_USER_ID}:******** http://${_DB_NODE_ARRAY[$i]}:5984/_up"
         displayMsg
         _URL=http://${_DB_NODE_ARRAY[$i]}:5984/_up
         # Determine if the node is up
         _res=$(curl -qSfsw '\n%{http_code}' -X GET -u ${_ADMIN_USER_ID}:${_ADMIN_PASSWORD} ${_URL})  2>/dev/null
         _RC=$?
         # Is the node running?
         if [ $_RC -eq 0 ]; then
            _MSG="Node ${_DB_NODE_ARRAY[$i]} is up."
            displayMsg
         elif [ $_RC -eq 22 -a "${_THIS_PC}" = "${_DB_NODE_ARRAY[$i]}" -a ${_MAINT_MODE} -eq 1  ]; then
            _MSG="Node ${_DB_NODE_ARRAY[$i]} is in maintenance mode."
            displayMsg
         else   
            _MSG="Node ${_DB_NODE_ARRAY[$i]} is not available."
            displayMsg
            _MSG="This is normal if you have not installed and configured Cloudant Local on that node."
            displayMsg
            _MSG="Install and configure Cloudant Local on the remaining nodes now and then rerun configure.sh on the first node."
            displayMsgAndExit
         fi
      done
      _MSG=" "
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
   fi

   # Determine if this is the first node in a multi-node configuration
   if [ "${_THIS_NODE}" = "d1" ]; then
      #_MSG="*** ******************************************************* ****"
      #_MSG="*** This step must only be run once on the first DB node    ****"
      #_MSG="*** of a Cloudant Local multi-node cluster!                 ****"
      #_MSG="*** ******************************************************* ****"
      #read -p "Join the remote nodes to this node? (y/n):" -n 1 -r
      #if [[ $REPLY =~ ^[Yy]$ ]]; then
         
      # Starting with the second node (1), traverse the nodes and determine if they were previously added
      for (( i = 1 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
         _MSG=" "
         displayMsg
         _MSG="--------------------------------------------------------------"
         displayMsg

         # Determine if the node has already been added
         _MSG=$(curl -X GET -X GET -qSfsw '\n%{http_code}' http://localhost:5986/nodes/cloudant@${_DB_NODE_ARRAY[$i]}) 2>/dev/null
         _RC=$?
         _HTTP_CODE=$(echo "${_res}" | tail -n1)
         if [ ${_RC} -ne 0 ]; then
            _MSG="Join ${_DB_NODE_ARRAY[$i]} to ${_DB_NODE_ARRAY[0]}"
            displayMsg
            _MSG="curl -X PUT http://localhost:5986/nodes/cloudant@${_DB_NODE_ARRAY[$i]} -d {}"
            displayMsg
            curl -X PUT http://localhost:5986/nodes/cloudant@${_DB_NODE_ARRAY[$i]} -d {}
            _RC=$?
            if [[ $_RC -ne 0 ]]; then
               _MSG="Error: Unable to join ${_DB_NODE_ARRAY[$i]} to ${_DB_NODE_ARRAY[0]}"
               displayMsgAndExit
            fi
         else   
            _MSG="Node ${_DB_NODE_ARRAY[$i]} already joined to ${_DB_NODE_ARRAY[0]}"
            displayMsg
         fi
      done

      _MSG="Display the current documents for localhost"
      displayMsg
      _MSG="curl -u ${_ADMIN_USER_ID}:******** http://localhost:5986/nodes/_all_docs?include_docs=true"
      displayMsg
      _URL=http://localhost:5986/nodes/_all_docs?include_docs=true
      _MSG="curl -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL

      _MSG="Display the current membership for the current node"
      displayMsg
      _URL=http://localhost:5984/_membership
      _MSG="curl -u ${_ADMIN_USER_ID}:******** ${_URL}"
      displayMsg
      displayURL
      _MSG="--------------------------------------------------------------"
      displayMsg
   else 
      _MSG=" "
      displayMsg
      _MSG="This computer is not the first node. 'Joining nodes' skipped..."
      displayMsg
   fi   
else 
   _MSG=" "
   displayMsg
   _MSG="This computer is a single node implementation. 'Joining nodes' skipped..."
   displayMsg
fi   

# Determine if this is the first node in a multi-node configuration or a single node
if [ "${_INSTALL_TYPE}" = "s" -o "${_THIS_NODE}" = "d1" ]; then
   _MSG="--------------------------------------------------------------"
   displayMsg
   _MSG="Determining if the stats DB exists..."
   displayMsg
   _RESPONSE=$(curl -qSfsw '\n%{http_code}' -u ${_ADMIN_USER_ID}:${_ADMIN_PASSWORD} ${_STATS_URL})  2>/dev/null
   # Get the return code
   _RC=$?
   # Get the HTTP response code
   _HTTP_CODE=$(echo "${_RESPONSE}" | tail -n1 )
   #echo "_res       = ${_RESPONSE}"
   #echo "_RC        = ${_RC}"
   #echo "_HTTP_CODE = ${_HTTP_CODE}"
   # If Cloudant is not running, the HTTP_CODE will be 000 and RC=7
   # If the stats DB exists, the HTTP_CODE will be 200 and RC=0
   # If the stats DB does not exist, the HTTP_CODE will be 404 and RC=22
   # If an invalid user ID/password specified, the HTTP_CODE will be 401
   if [ ${_HTTP_CODE} -eq 000 ]; then
      _MSG="*** Cloudant is not running ***"
      displayMsgAndExit
   elif [ ${_HTTP_CODE} -eq 200 ]; then
      _MSG="The stats DB exists. Skipping..."
      displayMsg
   elif [ ${_HTTP_CODE} -eq 404 ]; then
      _MSG="The stats DB does not exist. Creating..."
      displayMsg
      curl -X PUT -u ${_ADMIN_USER_ID}:${_ADMIN_PASSWORD} http://${_DB_NODE_ARRAY[0]}:5984/stats
      # Get the return code
      _STATS_RC=$?

      # Wait 10 seconds to wait for the DB to be created
      sleep 10

      _MSG="Verifying if the stats DB was created..."
      displayMsg
      _RESPONSE=$( curl -qSfsw '\n%{http_code}' -u ${_ADMIN_USER_ID}:${_ADMIN_PASSWORD} ${_STATS_URL})  2>/dev/null
      # Get the return code
      _RC=$?
      # Get the HTTP response code
      _HTTP_CODE=$(echo "${_RESPONSE}" | tail -n1 )
      if [ ${_HTTP_CODE} -eq 200 ]; then
         _MSG="The stats DB was successfully created."
         displayMsg
      else
         _MSG="*** Unable to create the stats DB. ***"
         _RC=${_STATS_RC}
         displayMsg
      fi
   fi

   _MSG="--------------------------------------------------------------"
   displayMsg
   _MSG="Determining if metrics DB exists..."
   displayMsg
   _RESPONSE=$(curl -qSfsw '\n%{http_code}' -u ${_METRICS_USER_ID}:${_METRICS_PASSWORD} ${_METRICS_URL}/${_METRICS_DBNAME})  2>/dev/null
   # Get the return code
   _RC=$?
   # Get the HTTP response code
   _HTTP_CODE=$(echo "${_RESPONSE}" | tail -n1 )
   if [ ${_HTTP_CODE} -eq 000 ]; then
      _MSG="*** Cloudant is not running ***"
      displayMsgAndExit
   elif [ ${_HTTP_CODE} -eq 200 ]; then
      _MSG="The ${_METRICS_DBNAME} DB exists. Skipping..."
      displayMsg
   elif [ ${_HTTP_CODE} -eq 404 ]; then
      _MSG="The ${_METRICS_DBNAME} DB does not exist. Creating..."
      displayMsg
      curl -X PUT -u ${_METRICS_USER_ID}:${_METRICS_PASSWORD} ${_METRICS_URL}/${_METRICS_DBNAME}
      # Get the return code
      _METRICS_RC=$?

      # Wait 10 seconds to wait for the DB to be created
      sleep 10

      _MSG="Verifying if the ${_METRICS_DBNAME} DB was created..."
      displayMsg
      _RESPONSE=$( curl -qSfsw '\n%{http_code}' -u ${_METRICS_USER_ID}:${_METRICS_PASSWORD} ${_METRICS_URL}/${_METRICS_DBNAME})  2>/dev/null
      # Get the return code
      _RC=$?
      # Get the HTTP response code
      _HTTP_CODE=$(echo "${_RESPONSE}" | tail -n1 )
      if [ ${_HTTP_CODE} -eq 200 ]; then
         _MSG="The ${_METRICS_DBNAME} DB was successfully created."
         displayMsg
      else
         _MSG="*** Unable to create the ${_METRICS_DBNAME} DB. RC=${_METRICS_RC} ***"
         _RC=${_METRICS_RC}
         displayMsg
         _MSG="Check the file /var/log/cloudant/metrics.log for the cause of the problem."
         displayMsg
      fi
   else
      _MSG="HTTP_CODE = $_HTTP_CODE"
      displayMsg
   fi
fi

_MSG=" "
displayMsg
_MSG="--------------------------------------------------------------"
displayMsg
_MSG="*** Configuration complete for ${_THIS_PC}. **** "
displayMsg
_MSG="--------------------------------------------------------------"
displayMsg

# Only do the following if this is NOT a LB only mode
if [ "${_THIS_NODE}" != "l1" -a "${_THIS_NODE}" != "l2" ]; then
   # Starting with the second node (1), Display the status of each node
   for (( i = 1 ; i < ${#_DB_NODE_ARRAY[@]} ; i++ )) do
      _MSG=" "
      displayMsg
      _MSG="--------------------------------------------------------------"
      displayMsg
      _MSG="Display the current membership for ${_DB_NODE_ARRAY[$i]}"
      displayMsg
      _MSG="curl -u ${_ADMIN_USER_ID}:******** http://${_DB_NODE_ARRAY[$i]}:5984/_membership"
      displayMsg
      _URL=http://${_DB_NODE_ARRAY[$i]}:5984/_membership
      displayURL
      _MSG=" "
      displayMsg
      _MSG="Display all of the databases for ${_DB_NODE_ARRAY[$i]}"
      displayMsg
      _MSG="curl -u ${_ADMIN_USER_ID}:******** http://${_DB_NODE_ARRAY[$i]}:5984/_all_dbs"
      displayMsg
      _URL=http://${_DB_NODE_ARRAY[$i]}:5984/_all_dbs
      displayURL

      _MSG="--------------------------------------------------------------"
      displayMsg
   done
fi


_MSG="Complete"
_RC=0
displayMsgAndExit

