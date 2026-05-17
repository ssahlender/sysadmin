#!/bin/bash -xv

FILE=Rocrail-debian13-ARM64.zip
URL=https://www.rocrail.online/rocrail-snapshot/Debian/$FILE

if [ -f $FILE ]; then
rm $FILE
fi

wget $URL

systemctl stop rocrail

unzip -o $FILE

systemctl start rocrail
