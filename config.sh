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
	
	
echo "Install needed packages? (ie sudo, build-essential, rpi-update, usbutils, wifi tools, usb tools, unzip, etc)? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
	apt-get -y install sudo
	sudo apt-get -y install raspi-config
	sudo apt-get -y install file
	sudo apt-get -y install build-essential
	sudo apt-get -y install curl
	sudo apt-get -y install usbutils	
	sudo apt-get -y install iptables
	sudo apt-get -y install nano
	sudo apt-get -y install wireless-tools 
	sudo apt-get -y install rpi-update
	sudo apt-get -y install libnl-3-dev
	sudo apt-get -y install libnl-genl-3-dev
	sudo apt-get -y install libnl-dev
	sudo apt-get -y install libssl-dev
	sudo apt-get -y install iw
	sudo apt-get -y install git
	sudo apt-get -y install unzip
	sudo apt-get -y install dkms
	sudo apt-get -y install bc
	sudo apt-get install raspberrypi-kernel-headers

	
fi
##########################################################################################################################################################

#Resize SD CARD file
echo "Resize SD Card? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
	sudo raspi-config
fi
##########################################################################################################################################################

#Update Pi
echo "Update Raspberry Pi? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
	sudo rpi-update
fi

############################################################################################################################################################

#Disable Onboard WiFi 
echo "If you're running RPI3 do you want to disable onboard WIFI? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then

        sudo echo "blacklist brcmfmac" >> /etc/modprobe.d/brcmfmac.conf

fi

############################################################################################################################################################

#Install WiFi Drivers
echo "Attempt to install Wifi Drivers? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
    sudo wget http://www.fars-robotics.net/install-wifi -O /usr/bin/install-wifi
    sudo chmod +x /usr/bin/install-wifi

    sudo install-wifi
    echo "auto wlan0">>$interfaces_file
    echo "iface wlan0 inet dhcp">>$interfaces_file
    sudo ifup wlan0

    
fi

############################################################################################################################################################

#Install headers Pi
echo "Install headers? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
	sudo apt-get -y install bc
	sudo apt-get -y install libncurses5-dev
	sudo apt-get -y install python

	# Get rpi-source
	sudo wget https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source

	# Make it executable
	sudo chmod +x /usr/bin/rpi-source

	# Tell the update mechanism that this is the latest version of the script
	/usr/bin/rpi-source -q --tag-update

	# Get the kernel files thingies.
	rpi-source
fi
##########################################################################################################################################################

##########################################################################################################################################################
#List Network Interfaces and input wired and wireless nic device names
echo "The following interfaces were found on your Pi"
ifconfig -a | sed 's/[ \t].*//;/^$/d'
echo "Enter Wired interface which will be connected to Internet"
read wired_nic
echo "Enter WLAN interface which will be used for AP"
read wlan_nic


##########################################################################################################################################################
#Configure Interfaces file
echo "Configure Interfaces? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
	sudo cp $interfaces_file /etc/network/interfaces$now
	sudo rm -f $interfaces_file
	echo "auto lo">>$interfaces_file
	echo "iface lo inet loopback">>$interfaces_file
fi
##########################################################################################################################################################
#configure wireless nic appropriately
echo "How will wireless connection be configured? (Note: Hostapd entry will point to /etc/hostapd/hostapd.conf) (Enter 1 or 2 or any other key to skip)"
echo "1) Static"
echo "2) DHCP"

read input
if [ $input = "1" ];
then
                
	echo "Config WLAN using Static"
	echo "Enter Static IP Address for WLAN"
	read wlanstaticip
	echo "Enter Netmask for WLAN"
	read wlannetmask
	echo "auto $wlan_nic">>$interfaces_file	
	echo "allow-hotplug $wlan_nic">>$interfaces_file
	echo "iface $wlan_nic inet static">>$interfaces_file
	echo "hostapd /etc/hostapd/hostapd.conf">>$interfaces_file
	echo "address $wlanstaticip">>$interfaces_file
	echo "netmask $wlannetmask">>$interfaces_file
fi

if [ $input = "2" ];
then

	echo "Config WLAN using DHCP"
	echo "auto $wlan_nic">>$interfaces_file
	echo "iface $wlan_nic inet dhcp">>$interfaces_file
fi

##########################################################################################################################################################
#configure wired nic appropriately
echo "How will wired connection be configured? (Enter 1 or 2 or any other key to skip)"
echo "1) Static"
echo "2) DHCP"

read input
		
if [ $input = "1" ];
then
	echo "Config Wired using static"
	echo "Enter Static IP Address"
	read wiredstaticip
	echo "Enter Netmask"
	read wirednetmask
	echo "Enter Gateway"
	read wiredgateway
	echo "Enter DNS Server"
	read wireddnsserver
	echo "auto $wired_nic">>$interfaces_file	
	echo "iface $wired_nic inet static">>$interfaces_file
	echo "address $wiredstaticip">>$interfaces_file
	echo "netmask $wirednetmask">>$interfaces_file
	echo "gateway $wiredgateway">>$interfaces_file
	echo "dns-nameservers $wireddnsserver">>$interfaces_file
fi
if [ $input = "2" ];
then

	echo "Config wired using DHCP"
	echo "auto $wired_nic">>$interfaces_file
	echo "iface $wired_nic inet dhcp">>$interfaces_file
fi

##########################################################################################################################################################
#install hostapd
echo "Please enter what you would like your SSID to be?"
read SSID
echo "Please enter what you desired WLAN password?"
read wifipass
	
echo "Configure Wireless connection (Hostapd will be installed and configured)? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input

if [ $input = "1" ];
then
	echo "Configure Hostapd for 5G? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"
	read input1
	if [ $input1 = "1" ]; then
		$fiveg=1
	fi
	
	lsusb
	echo "The usb devices above were detected, is your device a Realtek chip based device? (Enter 1 or 2)"
	echo "1) Yes"
	echo "2) No"
	read isRealTek

	if [ $isRealTek = "1" ];
	then 
		#download and install Realtek hostapd
        	sudo apt-get install -y libnl-dev libssl-dev
        
       		# Remove any previous hostapd files
		sudo apt-get purge -y hostapd
		sudo rm /usr/local/bin/hostapd*
		sudo rm /usr/bin/hostapd*
		sudo rm /usr/sbin/hostapd*

		git clone https://github.com/cannonfodder728/hostapdrtl80211ac.git
		cd hostapdrtl80211ac/hostapd
		sudo make clean
		sudo make
		sudo make install
	fi
		
		
		sudo cp $hostapdconffile /etc/hostapd/hostapd$now
		sudo rm -f $hostapdconffile
		
		#Create Hostapd.conf file
		# WPA and WPA2 configuration
		sudo echo "logger_syslog=-1">>$hostapdconffile
		sudo echo "logger_syslog_level=2">>$hostapdconffile
		sudo echo "logger_stdout=-1">>$hostapdconffile
		sudo echo "logger_stdout_level=2">>$hostapdconffile

		sudo echo "interface=$wlan_nic">>$hostapdconffile
		sudo echo "driver=nl80211">>$hostapdconffile
		sudo echo "ssid=$SSID">>$hostapdconffile
		sudo echo "macaddr_acl=0">>$hostapdconffile
		sudo echo "auth_algs=1">>$hostapdconffile
		sudo echo "ignore_broadcast_ssid=0">>$hostapdconffile
		sudo echo "wpa=2">>$hostapdconffile
		sudo echo "wpa_passphrase=$wifipass">>$hostapdconffile
		sudo echo "wpa_key_mgmt=WPA-PSK">>$hostapdconffile
		sudo echo "wpa_pairwise=CCMP">>$hostapdconffile
		sudo echo "wme_enabled=1">>$hostapdconffile
		if [ $fiveg = "1" ];
		then 
			sudo echo "ieee80211ac=1">>$hostapdconffile
			sudo echo "channel=52">>$hostapdconffile
			sudo echo "hw_mode=a">>$hostapdconffile
			#sudo echo "vht_oper_chwidth=1">>$hostapdconffile
			#sudo echo "vht_capab=[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1]">>$hostapdconffile
			#sudo echo "vht_oper_centr_freq_seg0_idx=62">>$hostapdconffile

		else
			sudo echo "channel=11">>$hostapdconffile
			sudo echo "ieee80211n=1">>$hostapdconffile
			sudo echo "ht_capab=[HT40-][SHORT-GI-20][SHORT-GI-40]">>$hostapdconffile
		fi
		sudo update-rc.d hostapd defaults
		sudo update-rc.d hostapd enable
		sudo service hostapd start

		# echo "Done configuring hostapd.conf file"		
	
fi
##########################################################################################################################################################
#configure DHCP Server
echo "Configure DHCP Server? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ];
then

	echo "Please enter DHCP Server subnet (usually subnet for WLAN NIC)"
	read subnet
	echo "Please enter starting IP of DHCP range"
	read startip
	echo "Please enter ending IP of DHCP range"
	read endip
	echo "Please broadcast IP"
	read broadcastip

	echo "Installing DHCP Server for DHCP and DNS Services on WLAN"
	sudo apt-get install isc-dhcp-server
	sudo cp $dhcpconffile /etc/dhcp/dhcpd.conf.$now
	sudo rm -f $dhcpconffile
	sudo echo "subnet $subnet netmask 255.255.255.0">>$dhcpconffile

	sudo echo "{">>$dhcpconffile
	sudo echo "range $startip $endip;">>$dhcpconffile
	sudo echo "option broadcast-address $broadcastip;">>$dhcpconffile
	sudo echo "option routers $wlanstaticip;">>$dhcpconffile
	sudo echo "default-lease-time 600;">>$dhcpconffile
	sudo echo "max-lease-time 7200;">>$dhcpconffile
	sudo echo "option domain-name-servers 8.8.8.8, 8.8.4.4;">>$dhcpconffile
	sudo echo "}">>$dhcpconffile
	sudo echo "authoritative;">>$dhcpconffile

	sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server$now
	sudo rm -f /etc/default/isc-dhcp-server
	sudo echo "INTERFACES=$wlan_nic">>/etc/default/isc-dhcp-server

	sudo update-rc.d isc-dhcp-server enable
	sudo service isc-dhcp-server start
fi

##########################################################################################################################################################
#Configure time zone
echo "Would you like to change time zone?"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ]; then
	dpkg-reconfigure tzdata
fi
##########################################################################################################################################################
#Configure users
echo "Would you like to a new user?"
echo "1) Yes"
echo "2) No"
read input

if [ $input = "1" ]; then
	echo "Enter Username of new user"
	read user
	apt-get install sudo
	echo "adding user $user"
	adduser $user 
	adduser $user sudo
	sudo usermod -a -G sudo $user
	echo "Disable root account?"
	echo "1) Yes"
	echo "2) No"
	read input
	if [ $input = "1" ]; then
		echo "disabling root user"
		passwd -dl root
	fi
fi


##########################################################################################################################################################
#Configure sshd including new port

echo "Would you like to change default SSH port and reconfigure SSH keys?"
echo "1) Yes"
echo "2) No"
read changesshport
if [ $changesshport = "1" ]; then
        echo "Please enter on which port you would like SSH Server to listen?"
        read sshport
        sudo sed -i 's/Port 22/Port '$sshport'/g' /etc/ssh/sshd_config
                #echo "Port $sshport">>/etc/ssh/sshd_config
        sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config 
        sudo sed -i 's/Protocol 1/Protocol 2/g' /etc/ssh/sshd_config
        sudo sed -i 's/IgnoreRhosts no/IgnoreRhosts yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/HostbasedAuthentication yes/HostbasedAuthentication no/g' /etc/ssh/sshd_config
        sudo sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/g' /etc/ssh/sshd_config

        
        echo "Changed SSH Port"
		sudo rm /etc/ssh/ssh_host_*
		sudo dpkg-reconfigure openssh-server

fi


##########################################################################################################################################################
#install samba
echo "Would you like to install Samba Server?"
echo "1) Yes"
echo "2) No"
read samba
if [ $samba = "1" ];
then
	echo "Installing ExFat support"
	sudo apt-get install exfat-utils -y

	sudo apt-get install samba samba-common-bin
	echo "Please enter path to folder you would like to share (ie path to folder where external drive is mounted)"
	read sambashare
	sudo cp $smbconffile /etc/samba/smb.conf$now
	sudo rm -f $smbconffile
	sudo echo "[global]">> $smbconffile
	sudo echo "interfaces = $wlan_nic lo">> $smbconffile
	sudo echo "bind interfaces only = yes">> $smbconffile
	sudo echo "dns proxy = no">> $smbconffile
	sudo echo "[share]">> $smbconffile
	sudo echo "comment= Pi Home">> $smbconffile
	sudo echo "path=$sambashare">> $smbconffile
	sudo echo "guest ok = yes">> $smbconffile
	sudo echo "create mask = 0777">> $smbconffile
	sudo echo "comment = Backup drive">> $smbconffile
	sudo echo "directory mask = 0777">> $smbconffile
	sudo echo "browseable = yes">> $smbconffile
	sudo echo "writable = yes">> $smbconffile
	sudo echo "public=yes">>$smbconffile
	sudo echo "force user = root">> $smbconffile
	sudo echo "force group = root">> $smbconffile

	sudo echo "log file = /var/log/samba/log.%m">> $smbconffile
	sudo echo "max log size = 1000">> $smbconffile
	sudo echo "syslog = 0">> $smbconffile

	sudo echo "panic action = /usr/share/samba/panic-action %d">> $smbconffile
	sudo echo "server role = standalone server">> $smbconffile

	sudo echo "passdb backend = tdbsam">> $smbconffile
	sudo echo "obey pam restrictions = yes">> $smbconffile
	sudo echo "unix password sync = yes">> $smbconffile
	sudo echo "passwd program = /usr/bin/passwd %u">> $smbconffile
	sudo echo "passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully*\n">> $smbconffile
	sudo echo "pam password change = yes">> $smbconffile

	sudo echo "map to guest = bad user">> $smbconffile
	sudo smbpasswd -a pi
	sudo echo "Done setting up samba"

fi

##########################################################################################################################################################
#configure firewall
echo "Configure Firewall? (Enter 1 or 2)"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ];
then

	echo "setup firewall rules appropriately and startup script"

	sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

	sudo cp $rclocalfile /etc/rc.local$now

	sudo rm -f $rclocalfile
	touch $rclocalfile 
	sudo sed -i 's/#exit 0/#exit 0/g' $rclocalfile
	echo "sudo ifdown $wired_nic">>$rclocalfile
	echo "sudo ifup $wired_nic">>$rclocalfile
	echo "sleep 5">>$rclocalfile
	echo "sudo ifdown $wlan_nic">>$rclocalfile
	echo "sudo ifup $wlan_nic">>$rclocalfile
	echo "sleep 5">>$rclocalfile
    echo "ifconfig $wlan_nic | grep -q $wlan_nic && echo 'found $wlan_nic nothing to do'> /dev/kmsg || sudo install-wifi ">>$rclocalfile
	
	echo "service hostapd restart">>$rclocalfile
	echo "sleep 5">>$rclocalfile
	echo "service isc-dhcp-server restart">>$rclocalfile
	echo "exit 0">>$rclocalfile

	sudo iptables -F
	sudo iptables -t nat -A POSTROUTING -o $wired_nic -j MASQUERADE
	sudo iptables -A FORWARD -i $wired_nic -o $wlan_nic -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i $wlan_nic -o $wired_nic -j ACCEPT
	sudo iptables -A OUTPUT -p tcp --tcp-flags ALL ALL -j DROP
	sudo iptables -A OUTPUT -p tcp --tcp-flags ALL ACK,RST,SYN,FIN -j DROP
	sudo iptables -A OUTPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
	sudo iptables -A OUTPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
	sudo iptables -A OUTPUT -p tcp --tcp-flags ALL NONE -j DROP
	sudo rm -f /etc/iptables.ipv4.nat
	sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

	#sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

	sudo echo "up iptables-restore < /etc/iptables.ipv4.nat">> /etc/network/interfaces

	echo "Done setting up startup script with Firewall Rules"
fi
##########################################################################################################################################################
#Change Password
echo "Would you like to change root password?"
echo "1) Yes"
echo "2) No"
read changepass
myvariable=$USER
if [ $changepass = "1" ];
then
	echo "Enter new password"
	read S1
	echo "Re-Enter new password"
	read  S2
	if [ "$S1" = "$S2" ];
    then
		echo "$myvariable:$S1" | chpasswd
		echo "Password changed"
	
	else
		echo "Passwords didnt match, password NOT changed"
	fi
	
fi

##########################################################################################################################################################
#Remove unnecessary packages

echo "Remove Unnecessary packages? (Enter 1 or 2)"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ];
then
	echo "Removing Unncessary Packages"
	# GUI-related packages

	pkgs="
		avahi-daemon
		alsa-utils
		debian-reference-en 
		desktop-base 
		dillo 
		epiphany-browser
		gir1.2*
		gksu
		gnome-icon-theme
		gnome-themes-standard-data 
		gnome*
		gstreamer1.0-libav
		gstreamer1.0-omx 
		gstreamer1.0-plugins-bad gstreamer1.0-alsa
		gstreamer1.0-plugins-base
		gstreamer1.0-plugins-good 
		gstreamer1.0-x 
		gtk2-engines 
		idle 
		idle3 
		idle3 python3-tk
		java-common 
		libgtk-3-common 
		libreoffice*
		libx11-.*
		lightdm 
		lxde lxtask 
		lxde-icon-theme 
		lxpolkit
		menu-xdg 
		minecraft-pi 
		minecraft-pi 
		netsurf-gtk 
		nuscratch
		nuscratch 
		omxplayer
		oracle-java8-jdk
		penguinspuzzle
		penguinspuzzle 
		pistore
		python-minecraftpi 
		python-picamera 
		python-pifacecommon 
		python-pifacedigitalio
		python-pygame 
		python-serial 
		python-tk
		python3-minecraftpi 
		python3-numpy
		python3-picamera
		python3-pifacecommon 
		python3-pifacedigital-scratch-handler 
		python3-pifacedigitalio 
		python3-pygame 
		python3-rpi.gpio
		python-gpiozero
		python3-serial
		qt50-quick-particle-examples
		qt50-snapshot 
		raspberrypi-artwork
		raspberrypi-ui-mods
		scratch 
		smartsim 
		sonic-pi
		timidity
		weston
		wolfram-engine
		x11-common*
		x2x
		xinit
		xkb-data 
		xpdf 
		xserver-xorg 
		xserver-xorg-video-fbdev
		xserver-xorg-video-fbturbo
		zenity
		"
	
	# Remove packages
	for i in $pkgs; do
		sudo apt-get -y remove --purge $i
	done

	# Remove automatically installed dependency packages
	sudo apt-get -y autoremove


	echo "Updating Pi"
	#sudo apt-get update
	sudo apt-get clean
	sudo apt-get autoremove
	#echo "Installing Exfat Support"
	#echo "Upgrading Packages"
	#sudo apt-get upgrade
	echo "Done removing unnecessary packages and  updates"
	#sudo reboot
fi

##########################################################################################################################################################
#Finish up

echo "Config complete, would you like to reboot?"
echo "1) Yes"
echo "2) No"
read reboot
if [ $reboot = "1" ];
then
	echo "Updating and Upgrading Packages"
	sudo apt-get update
	sudo apt-get upgrade
	echo "Rebooting now!"
	sudo reboot
else
	exit 0 
fi


