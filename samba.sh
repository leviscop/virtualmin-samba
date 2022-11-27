#!/bin/bash

SMB_CONF=/etc/samba/smb.conf
SMB_CONF_DIR_USERS=/etc/samba/smb.conf.d/users
SMB_CONF_DIR_SUBUSERS=/etc/samba/smb.conf.d/subusers
SMB_INCLUDES=/etc/samba/includes.conf

USERS="$(/usr/sbin/virtualmin list-domains --user-only | sort -u)"

mkdir -p $SMB_CONF_DIR_USERS
mkdir -p $SMB_CONF_DIR_SUBUSERS
FILES_USERS="$(ls $SMB_CONF_DIR_USERS | sed 's/.conf//g')"
FILES_SUBUSERS="$(ls $SMB_CONF_DIR_SUBUSERS | sed 's/.conf//g')"
for USER in $FILES_USERS; do
        if [ "$(echo $USERS | grep -w $USER | wc -l)" = 0 ]; then
                useradd $USER
                smbpasswd -x $USER
                userdel $USER
                rm $SMB_CONF_DIR_USERS/$USER.conf
        fi
done
for USER in $USERS; do
        if [ ! -f "$SMB_CONF_DIR_USERS/$USER.conf" ]; then
                smbpasswd -a $USER -n
                echo -e "[$USER]\n\twriteable = yes\n\tpath = /home/$USER\n\tvalid users = $USER" > $SMB_CONF_DIR_USERS/$USER.conf
        fi
        DOMAINS="$(/usr/sbin/virtualmin list-domains --user $USER --subserver --name-only)"
        for DOMAIN in $DOMAINS; do
                SUBUSERS="$(/usr/sbin/virtualmin list-users --domain $DOMAIN --name-only | sed 's/@/-/g')"
                for SUBUSER in $FILES_SUBUSERS; do
                        if [ "$(echo $SUBUSERS | grep -w $SUBUSER | wc -l)" = 0 ]; then
                                useradd $SUBUSER
                                smbpasswd -x $SUBUSER
                                userdel $SUBUSER
                                rm $SMB_CONF_DIR_USERS/$SUBUSER.conf
                        fi
                done
                for SUBUSER in $SUBUSERS; do
                        if [ ! -f "$SMB_CONF_DIR_SUBUSERS/$SUBUSER.conf" ]; then
                                smbpasswd -a $SUBUSER -n
                                echo -e "[$SUBUSER]\n\twriteable = yes\n\tpath = /home/$USER/domains/$DOMAIN\n\tvalid users = $SUBUSER" > $SMB_CONF_DIR_SUBUSERS/$SUBUSER.conf
                        fi
                done
        done
done

if ! grep -q 'include = '"${SMB_INCLUDES}" $SMB_CONF ; then
   echo 'include = '"${SMB_INCLUDES}" | tee -a $SMB_CONF > /dev/null
fi

ls "${SMB_CONF_DIR_USERS}"* | sed -e 's/^/include = /' > $SMB_INCLUDES
ls "${SMB_CONF_DIR_SUBUSERS}"* | sed -e 's/^/include = /' >> $SMB_INCLUDES
