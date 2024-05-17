#!/bin/bash
#KW 2019

date=$(date +'%F')
currentdate=$(date +'%s')
currentdatedays=$(($currentdate/86400))
emailaddress=youremail@address
SMTP=yoursmtpservername

#Create a user with a keytab
kinit -k -t /home/sreports/sreports.keytab sreports@DOMAIN

#set -x

touch /tmp/audit-$date.txt
touch /tmp/prd-idm-active-users-$date.csv
touch /tmp/displayname-$date.txt
touch /tmp/active-$date.txt
touch /tmp/groups-$date.txt
touch /tmp/ein-$date.txt
touch /tmp/mostrecentauth-$date.txt

echo "--------------------------------------------------------" >> /tmp/audit-$date.txt
echo "PRD IDM Status Report - $date" >> /tmp/audit-$date.txt
echo "--------------------------------------------------------" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt

echo "Please find attached a report contaning the following information on active users:" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt
echo "Display Name - User Login - Group Membership - EIN - Last successful Auth" >> /tmp/audit-$date.txt
echo "-----------------------------------------------------------------------------------------" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt

echo "Display Name" >> /tmp/displayname-$date.txt
echo "Member of group" >> /tmp/groups-$date.txt
echo "EIN" >> /tmp/ein-$date.txt
echo "Last Auth" >> /tmp/mostrecentauth-$date.txt

echo "----------------------------------------" >> /tmp/audit-$date.txt
echo "User and Group Summary" >> /tmp/audit-$date.txt
echo "----------------------------------------" >> /tmp/audit-$date.txt

numusers=$(ipa user-find | grep "Number of entries returned" | awk '{print $5'})
echo "There are $numusers users provisioned on the PRD IDM Service" >> /tmp/audit-$date.txt

numdisabled=$(ipa user-find  | grep "Account disabled: True" | wc -l)
echo "There are $numdisabled users disabled on the PRD IDM Service" >> /tmp/audit-$date.txt

usergroups=$(ipa group-find | grep "Number of entries returned" | awk '{print $5'})
numusergroups=$((usergroups -2))

echo "There are $numusergroups user groups on the PRD IDM Service" >> /tmp/audit-$date.txt
echo "----------------------------" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt

ipa user-find | grep "User login" | awk {'print $3'} > /tmp/users-$date.txt
sed -i '/admin/d' /tmp/users-$date.txt

for i in `cat /tmp/users-$date.txt`; do ipa user-show $i | grep 'Account disabled: False'; if [ $? -eq 0 ]; then echo $i >> /tmp/active-$date.txt; else echo $i  >> /tmp/inactive-$date.txt; fi done > /dev/null 2>&1

#Display Name

for i in $(cat /tmp/active-$date.txt); do

DISPLAY=$(ipa user-show $i --all | grep "Display name" | awk {'print $3" "$4" "$5'})

echo $DISPLAY >> /tmp/.name-$i.txt; cat /tmp/.name-$i.txt | while read user; do if [[ -z "$user" ]]; then echo "-" >> /tmp/displayname-$date.txt; else echo "$DISPLAY" >> /tmp/displayname-$date.txt; fi; done; done;  > /dev/null 2>&1

#Groups

for i in $(cat /tmp/active-$date.txt); do

GROUP=$(ipa user-show $i | egrep "Member of groups" | awk {'print $4 $5 $6 $7 $8'})

echo $GROUP >> /tmp/.group-$i.txt; cat /tmp/.group-$i.txt | while read group; do if [[ -z "$group" ]]; then echo "-" >> /tmp/groups-$date.txt; else echo "$GROUP" >> /tmp/groups-$date.txt; fi; done; done;  > /dev/null 2>&1

sed -i 's/,/ /g' /tmp/groups-$date.txt
sed -e s/ipausers//g -i /tmp/groups-$date.txt

#EIN

for i in `cat /tmp/active-$date.txt`; do

EIN=$(ipa user-show $i --all | egrep "Employee Number" | awk '{print $3}');

echo $EIN >> /tmp/.ein-$i.txt; cat /tmp/.ein-$i.txt | while read ein; do if [[ -z "$ein" ]]; then echo "-" >> /tmp/ein-$date.txt; else echo "$EIN" >> /tmp/ein-$date.txt; fi; done; done;  > /dev/null 2>&1

sed -i 's/,/ /g' /tmp/ein-$date.txt

#Disabled
for i in `cat /tmp/inactive-$date.txt`; do ipa user-show $i | egrep 'User login|First name|Last name|Account disabled' | awk -vORS=, '{print $3}' | sed 's/,$/\n/'; done >> /tmp/disabled-$date.csv

#Last successful Auth

for i in $(cat /tmp/active-$date.txt); do
        ipa user-status $i --all | grep "Last successful authentication" | awk '{print $4}' | cut -c1-14 > /tmp/.user.$i.txt;
        cat /tmp/.user.$i.txt | while read user;
do
        if [ $user = "N/A" ] ; then
        echo "N/A" >> /tmp/.lastsuccauth-$i.txt
else
        lastauthyear=$(echo "$user" | cut -c1-4);
        lastauthmonth=$(echo "$user" | cut -c5-6);
        lastauthday=$(echo "$user" | cut -c7-8);
        lastauthhour=$(echo "$user" | cut -c9-10);
        lastauthmin=$(echo "$user" | cut -c11-12);
        lastauthsec=$(echo "$user" | cut -c13-14);
        userlastauthepoch="$lastauthyear-$lastauthmonth-$lastauthday $lastauthhour:$lastauthmin:$lastauthsec +0000";
        userlastauthepochdate=`date -d "${userlastauthepoch}" '+%s'`;
        userlastauthdays=$(($userlastauthepochdate/86400));
        dayssincelastsuccauth=`expr $currentdatedays - $userlastauthdays`;

echo "$dayssincelastsuccauth" >> /tmp/.lastsuccauth-$i.txt

fi
done
done

for i in $(cat /tmp/active-$date.txt); do

mostrecentsuccauth=$(cat /tmp/.lastsuccauth-$i.txt | sort -V | head -1);
echo "$mostrecentsuccauth" >> /tmp/mostrecentauth-$date.txt

done

sed -i '1s/^/User Login\n/' /tmp/active-$date.txt
paste -d, /tmp/displayname-$date.txt /tmp/active-$date.txt /tmp/groups-$date.txt /tmp/ein-$date.txt /tmp/mostrecentauth-$date.txt > /tmp/prd-idm-active-users-$date.csv


echo "-------------------" >> /tmp/audit-$date.txt
echo "Disabled Users:" >> /tmp/audit-$date.txt
echo "-------------------" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt
cat /tmp/disabled-$date.csv | grep True | awk -F',' '{print $1" - "$2" "$3}' >> /tmp/audit-$date.txt

echo "" >> /tmp/audit-$date.txt
echo "-----------------------------------------------" >> /tmp/audit-$date.txt
echo "Role Based IDM Privileged Users:" >> /tmp/audit-$date.txt
echo "-----------------------------------------------" >> /tmp/audit-$date.txt
echo "" >> /tmp/audit-$date.txt

ipa role-find | grep "Role name" | awk {'print $3" "$4" "$5'} >/tmp/rbac-$date.csv

sed -i 's/\s*$//' /tmp/rbac-$date.csv

cat /tmp/rbac-$date.csv | while read i; do
        echo "----------------------------"; ipa role-show "$i" | egrep 'Role name|Member users'; done >> /tmp/audit-$date.txt
echo "----------------------------" >> /tmp/audit-$date.txt

mail -S smtp=$SMTP -s "IDM Report - $date " -a /tmp/prd-idm-active-users-$date.csv -- $emailaddress < /tmp/audit-$date.txt

#Clean Up

rm /tmp/.user.*
rm /tmp/.lastsuccauth-*
rm /tmp/.ein-*
rm /tmp/.group-*
rm /tmp/.name-*
rm /tmp/groups-$date.txt
rm /tmp/mostrecentauth-$date.txt
rm /tmp/displayname-$date.txt
rm /tmp/ein-$date.txt
rm /tmp/disabled-$date.csv
rm /tmp/users-$date.txt
#rm /tmp/audit-$date.txt
rm /tmp/rbac-$date.csv
rm /tmp/prd-idm-active-users-$date.csv
#rm /tmp/inactive-$date.txt
#rm /tmp/active-$date.txt
