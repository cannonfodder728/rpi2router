#!/bin/bash

#link for rtl 8192 drivers  wget https://dl.dropboxusercontent.com/u/80256631/8192eu-4.1.13-v7-826.tar.gz
#wget https://dl.dropboxusercontent.com/u/80256631/8812au-4.1.18-v7-846.tar.gz
#wget https://dl.dropboxusercontent.com/u/80256631/install-wifi.tar.gz
#https://github.com/lostincynicism/hostapd-rtl8188/archive/master.zip
#https://github.com/diederikdehaas/rtl8812AU/archive/driver-4.3.22-beta.zip

hostapdconffile='/etc/hostapd/hostapd.conf'
interfaces_file='/etc/network/interfaces'
dhcpconffile='/etc/dhcp/dhcpd.conf'
smbconffile='/etc/samba/smb.conf'
rclocalfile="/etc/rc.local"
now=$(date +"%m_%d_%Y_%H_%M_%S")

apt-get -y install sudo


##########################################################################################################################################################
#Resize SD CARD file

echo "Resize SD Card? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
        sudo apt-get -y install raspi-config
        sudo raspi-config
fi

##########################################################################################################################################################
#Set Time

echo "Set Time? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
        sudo apt-get -y install dpkg-reconfigure
        sudo dpkg-reconfigure tzdata
fi
