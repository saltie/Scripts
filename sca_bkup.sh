#!/bin/bash

#Scality Backups
#KW 2021

#set -x

DATE=`date +%Y%m%d`
HOST=`hostname | cut -d. -f1`
SCA_BKP_DIR=/var/lib/scality/backup/archives
BKP_DIR=/mnt/nfs/infrabkup/sca
backup_files=$SCA_BKP_DIR/weekly_*_$DATE*.tar.gz
LOG=/var/log/sncr_scality_backup.log

echo "*** Starting backup on $(date -R) ***" >> $LOG

if ls $backup_files &>/dev/null;
then

mkdir -p $BKP_DIR/$HOST
cp -Rn $backup_files $BKP_DIR/$HOST
echo "Files backed up on $(date -R)" >> $LOG

else

echo "No back up files exist on $(date -R)" >> $LOG

fi

