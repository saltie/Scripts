#!/bin/bash
#v1.1 - Added checks

#set -x

#Script to stop / start instances in a compartment

PATH=$PATH:/usr/local/bin
export PYTHONWARNINGS='ignore'
DATE=`date +%F-%H:%M`
LOG="/tmp/instance_action-$DATE.log"
SMTP="SMTP Server"
EMAIL="user@domain.com"

function usage {
  echo "$(basename $0) usage: "
  echo "    -c COMPARTMENT OCID"
  echo "    -action stop|start"
  echo ""
  exit 1
}

while [[ $# -gt 1 ]]
do
    key="$1"
    case $key in
      -c)
      COMP_OCID="$2"
      shift
      ;;
      -action)
      ACTION="$2"
      shift
      ;;
      *)
      usage
      shift
      ;;
  esac
  shift
done

[ ! -z ${COMP_OCID} ] && [ ! -z ${ACTION} ] || usage

GETINSTANCES=`oci compute instance list -c $COMP_OCID --auth instance_principal | egrep '\"id"' | cut -d: -f2 | sed -e 's/^ "//' -e 's/"\,$//'`

echo "---------------------------------------------------------------------------------------------------" >> $LOG
echo "$DATE" >> $LOG
echo "Beginning ACTION $ACTION on instance(s) in compartment $COMP_OCID" >> $LOG
echo "---------------------------------------------------------------------------------------------------" >> $LOG
echo "" >> $LOG

for i in $GETINSTANCES; do

GETINSTSTATUS=`oci compute instance get --instance-id $i --auth instance_principal |  egrep '\"lifecycle-state"' | cut -d: -f2 | sed -e 's/^ "//' -e 's/"\,$//'`

if [[ $ACTION == stop && $GETINSTSTATUS == "RUNNING" ]]; then

oci compute instance action --action $ACTION --instance-id $i --auth instance_principal
echo "Node $i has been STOPPED" >> $LOG

elif [[ $ACTION == stop && $GETINSTSTATUS == "STOPPED" ]]; then

echo "Node $i already in STOPPED state. No action taken." >> $LOG

elif [[ $ACTION == start && $GETINSTSTATUS == "STOPPED" ]]; then

oci compute instance action --action $ACTION --instance-id $i --auth instance_principal
echo "Node $i now RUNNING" >> $LOG

elif [[ $ACTION == start && $GETINSTSTATUS == "RUNNING" ]]; then
echo "Node $i already in RUNNING state. No action taken." >> $LOG

else
echo "$ACTION not valid input. Aborted." >> $LOG
mail -S smtp=$SMTP -s "The ACTION $ACTION has failed" < $LOG -- $EMAIL
exit 1

fi
done

echo "" >> $LOG
echo "---------------------------------------------------------------------------------------------------" >> $LOG
echo "Completed ACTION $ACTION on instance(s) in compartment $COMP_OCID" >> $LOG
echo "---------------------------------------------------------------------------------------------------" >> $LOG

mail -S smtp=$SMTP -s "The ACTION $ACTION has been successful" < $LOG -- $EMAIL
