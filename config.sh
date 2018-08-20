#!/bin/bash


hostapdconffile="/etc/hostapd/hostapd.conf"
sudo mkdir /etc/hostapd
interfaces_file="/etc/network/interfaces"
dhcpconffile="/etc/dhcp/dhcpd.conf"
rclocalfile="/etc/rc.local"
now=$(date +"%m_%d_%Y_%H_%M_%S")

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

#type sudo &> /dev/null && echo found sudo || apt-get -y install sudo

type sudo &> /dev/null && echo found sudo || echo didnt find sudo && apt-get -y install hostapd
sudo apt-get -y update

type raspi-config &> /dev/null && echo found raspi-config || echo didnt find raspi-config && sudo apt-get -y install raspi-config
type pgrep &> /dev/null && echo found pgrep || echo didnt find pgrep && sudo apt-get -y install pgrep
type htop &> /dev/null && echo htop || echo didnt find htop && sudo apt-get -y install htop

#apt-get -y install sudo
#sudo apt-get -y dpkg-reconfigure

##########################################################################################################################################################
#Resize SD CARD file
echo "Resize SD Card? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read -r input
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

##########################################################################################################################################################
#Install packages
echo "Install needed packages? (ie sudo, build-essential, rpi-update, usbutils, wifi tools, usb tools, unzip, etc)? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
	sudo apt-get -y update && sudo apt-get -y upgrade
	sudo apt-get -y install htop screen iperf libnl-route-3-200 libncurses5-dev lshw bridge-utils libnl-dev libssl-dev file libnl-3-200 libnl-genl-3-200 build-essential curl usbutils iptables nano wireless-tools iw git unzip dkms bc python raspberrypi-kernel-headers rpi-update 
	sudo rpi-update
fi

############################################################################################################################################################
#Disable Onboard WiFi 
rpi3=$(cat /proc/device-tree/model | grep -ie 'Raspberry Pi 3' | wc -l)
if [ $rpi3 -ge 1 ];
then
	echo "Looks like you're running RPI3.  Do want to disable onboard WIFI? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"

	read input
	if [ $input = "1" ];
	then
        	sudo echo "blacklist brcmfmac" >> /etc/modprobe.d/brcmfmac.conf
		rmmod brcmfmac
		sudo echo "Disabled Onboard Wifi"
	fi
##########################################################################################################################################################
#Disable Bluetooth
	echo "Disable bluetooth? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"

	read input
	if [ $input = "1" ];
	then
        	#sudo echo "blacklist brcmfmac" >> /etc/modprobe.d/brcmfmac.conf
        	#rmmod brcmfmac
        	#sudo echo "Disabled Onboard Wifi"
		sudo echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt
	fi
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

fi

############################################################################################################################################################
#Install headers Pi
echo "Install headers? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then	
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
#List Network Interfaces and input wired and wireless nic device names
echo "The following interfaces were found on your Pi"
ifconfig -a | sed 's/[ \t].*//;/^$/d'

echo "Enter Wired interface which will be connected to Internet"
read wired_ext_nic

echo "Enter WLAN interface which will be used for  Internal Network (Press Enter to skip)"
read wlan_int_nic

echo "Enter Wired interface which will be used for Internal Network (Press Enter to skip)"
read wired_int_nic

#read -p "Enter up to two interfaces which will be added to bridge for internal network (if you have wireless and wired enter both those interfaces with spaces in between)" intnic1 intnic2

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

	if [ -z "$wlan_int_nic" ];
	then
		echo ""
	else
		echo "Internal WLAN nic set, configuring interfaces file"
		echo "auto $wlan_int_nic">>$interfaces_file
		echo "allow-hotplug $wlan_int_nic">>$interfaces_file
		echo "iface $wlan_int_nic inet manual">>$interfaces_file
	fi

	if [ -z "$wired_int_nic" ];
	then
		echo ""
	else
		echo "Internal wired nic set, configuring interfaces file"
		echo "auto $wired_int_nic">>$interfaces_file
		echo "allow-hotplug $wired_int_nic">>$interfaces_file
		echo "iface $wired_int_nic inet manual">>$interfaces_file
    fi
fi

##########################################################################################################################################################
#configure internal network appropriately
echo "How will internal connection be configured? (Note: Hostapd entry will point to /etc/hostapd/hostapd.conf) (Enter 1 or 2 or any other key to skip)"
echo "1) Static"
echo "2) DHCP"

read input
if [ $input = "1" ];
then
	echo "Config Bridge Interface"
	echo "Enter Static IP Address for internal network"
	read intstaticip
	echo "Enter Netmask for internal network"
	read intnetmask
	echo "Enter Broadcast Address for internal network"
	read intnetbroadcast

	#echo "hostapd /etc/hostapd/hostapd.conf">>$interfaces_file
	echo "auto br0">>$interfaces_file	
	echo "iface br0 inet static">>$interfaces_file
	if [ -z "$wired_int_nic" ];
	then
		echo "bridge_ports $wlan_int_nic">>$interfaces_file

	else
		echo "bridge_ports $wlan_int_nic $wired_int_nic">>$interfaces_file
	fi
	echo "address $intstaticip">>$interfaces_file
	echo "broadcast $intnetbroadcast">>$interfaces_file
	echo "netmask $intnetmask">>$interfaces_file

fi

#if [ $input = "2" ];
#then
#	echo "Config Backup using DHCP"
#	echo "auto $wlan_nic">>$interfaces_file
#	echo "iface $wlan_nic inet dhcp">>$interfaces_file
#fi

##########################################################################################################################################################
#configure external wired nic appropriately
echo "How will external (Internet facing) connection be configured? (Enter 1 or 2 or any other key to skip)"
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
	echo "auto $wired_ext_nic">>$interfaces_file
	echo "iface $wired_ext_nic inet static">>$interfaces_file
	echo "address $wiredstaticip">>$interfaces_file
	echo "netmask $wirednetmask">>$interfaces_file
	echo "gateway $wiredgateway">>$interfaces_file
	echo "dns-nameservers $wireddnsserver">>$interfaces_file
fi

if [ $input = "2" ];
then
	echo "Config wired using DHCP"
	echo "auto $wired_ext_nic">>$interfaces_file
	echo "iface $wired_ext_nic inet dhcp">>$interfaces_file
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
fiveg=0
if [ $input = "1" ];
then
	echo "Configure Hostapd for 5G? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"
	read input1
	if [ $input1 = "1" ]; then
		fiveg="1"
	fi
	
	if [ -z "$now" ];
	then
      		now=$(date +"%m_%d_%Y_%H_%M_%S")
      		echo "now  variable not seting using $now"
	fi
	
	if [ -z "$hostapdconffile" ];
	then
		echo "Hostapd Config file variable not seting using $hostapdconffile"
		hostapdconffile="/etc/hostapd/hostapd.conf"
	fi
	
	if [ -z "$SSID" ];
	then
		SSID="wifi"
	    	echo "SSID variable not seting using $SSID"
	fi
	
	if [ -z "$wlan_int_nic" ];
	then
	      	wlan_int_nic="wlan0"
	      	echo "wlan nic variable not seting using $wlan_int_nic"
	fi
	
	sudo apt-get -y install hostapd
	
	
	#Create Hostapd.conf file
	sudo cp $hostapdconffile /etc/hostapd/hostapd.conf.$now
	sudo echo "driver=nl80211">>$hostapdconffile
	sudo echo "#logger_syslog=-1">>$hostapdconffile
	sudo echo "#logger_syslog_level=2">>$hostapdconffile
	sudo echo "#logger_stdout=-1">>$hostapdconffile
	sudo echo "#logger_stdout_level=2">>$hostapdconffile
	sudo echo "interface=$wlan_int_nic">>$hostapdconffile
	sudo echo "bridge=br0">>$hostapdconffile

	sudo echo "ssid=$SSID">>$hostapdconffile
	sudo echo "macaddr_acl=0">>$hostapdconffile
	sudo echo "auth_algs=1">>$hostapdconffile
	sudo echo "ignore_broadcast_ssid=0">>$hostapdconffile
	sudo echo "wpa=2">>$hostapdconffile
	sudo echo "wpa_passphrase=$wifipass">>$hostapdconffile
	sudo echo "wpa_key_mgmt=WPA-PSK">>$hostapdconffile
	sudo echo "wpa_pairwise=CCMP">>$hostapdconffile
	sudo echo "require_ht=1">>$hostapdconffile
	sudo echo "wmm_enabled=1">>$hostapdconffile
	sudo echo "ieee80211n=1">>$hostapdconffile
	if [ $fiveg = "1" ];
	then 
		sudo echo "ieee80211ac=1">>$hostapdconffile
		sudo echo "channel=36">>$hostapdconffile
		sudo echo "hw_mode=a">>$hostapdconffile
		sudo echo "require_vht=1">>$hostapdconffile
		sudo echo "vht_oper_chwidth=0">>$hostapdconffile
		sudo echo "#vht_capab=[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1]">>$hostapdconffile
		sudo echo "#vht_oper_centr_freq_seg0_idx=62">>$hostapdconffile
	else
		sudo echo "channel=6">>$hostapdconffile
		sudo echo "#ht_capab=[HT40-][SHORT-GI-40][DSSS_CCK-40]">>$hostapdconffile
		sudo echo "ht_capab=[HT40]">>$hostapdconffile
		sudo echo "hw_mode=g">>$hostapdconffile
		sudo echo "#noscan=1">>$hostapdconffile
	fi
	sudo echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"">>/etc/default/hostapd
	
	echo "Done configuring hostapd.conf file"

	sudo update-rc.d hostapd defaults && sudo update-rc.d hostapd enable &&	sudo service hostapd start
	echo "Done configuring hostapd"
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
	sudo apt-get -y install isc-dhcp-server
	sudo cp $dhcpconffile /etc/dhcp/dhcpd.conf.$now
	sudo rm -f $dhcpconffile
	sudo echo "subnet $subnet netmask 255.255.255.0">>$dhcpconffile

	sudo echo "{">>$dhcpconffile
	sudo echo "range $startip $endip;">>$dhcpconffile
	sudo echo "option broadcast-address $broadcastip;">>$dhcpconffile
	sudo echo "option routers $intstaticip;">>$dhcpconffile
	sudo echo "default-lease-time 600;">>$dhcpconffile
	sudo echo "max-lease-time 7200;">>$dhcpconffile
	sudo echo "option domain-name-servers 8.8.8.8, 8.8.4.4;">>$dhcpconffile
	sudo echo "}">>$dhcpconffile
	sudo echo "authoritative;">>$dhcpconffile

	sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server$now
	sudo rm -f /etc/default/isc-dhcp-server
	sudo echo "INTERFACES=br0">>/etc/default/isc-dhcp-server

	sudo update-rc.d isc-dhcp-server enable
	sudo service isc-dhcp-server start
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
	sudo echo "Port $sshport" >> /etc/ssh/sshd_config
	sudo echo "PermitRootLogin no">> /etc/ssh/sshd_config 
	sudo echo "Protocol 2">> /etc/ssh/sshd_config
	sudo echo "IgnoreRhosts yes">> /etc/ssh/sshd_config
	sudo echo "HostbasedAuthentication no">> /etc/ssh/sshd_config
	sudo echo "PermitEmptyPasswords no">> /etc/ssh/sshd_config
	echo "Changed SSH Port"
	echo "Reconfiguring OpenSSH Keys"
	
	sudo rm /etc/ssh/ssh_host_*
	sudo dpkg-reconfigure openssh-server
fi

##########################################################################################################################################################
#Configure fail2ban
echo "Would you like to install Fail2Ban?" 
echo "1) Yes" 
echo "2) No"
read fail2ban
if [ $fail2ban = "1" ];
then
        sudo apt-get -y install fail2ban
        sudo echo "installed fail2ban"
        # copy the example configuration file and make it live
        sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        if [ -z "$sshport" ];
        then
                sshportfail2ban=22
        else
                sshportfail2ban=$sshport
        fi
        #echo $sshportfail2ban
        sudo echo "using $sshportfail2ban as ssh port"
        sudo echo "[ssh]" >> /etc/fail2ban/jail.local
        sudo echo "enabled = true" >> /etc/fail2ban/jail.local
        sudo echo "port = $sshportfail2ban" >> /etc/fail2ban/jail.local
        sudo echo "filter = sshd" >> /etc/fail2ban/jail.local
        sudo echo "logpath = /var/log/auth.log" >> /etc/fail2ban/jail.local
        sudo echo "banaction = iptables-allports ; ban retrys on any port" >> /etc/fail2ban/jail.local
        sudo echo "bantime = 600 ; ip address is banned for 10 minutes" >> /etc/fail2ban/jail.local
        sudo echo "maxretry = 10 ; allow the ip address retry a max of 10 times" >> /etc/fail2ban/jail.local
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
	echo "sudo ifdown $wired_ext_nic">>$rclocalfile
	echo "sudo ifup $wired_ext_nic">>$rclocalfile
	
	echo "sleep 5">>$rclocalfile
	echo "sudo ifdown br0">>$rclocalfile
	echo "sudo ifup br0">>$rclocalfile
	echo "sleep 5">>$rclocalfile
    echo "sudo ifconfig $wlan_int_nic | grep -q $wlan_int_nic && echo 'found $wlan_int_nic nothing to do'> /dev/kmsg || sudo /usr/bin/install-wifi ">>$rclocalfile
	
	echo "sudo hostapd -B /etc/hostapd/hostapd.conf">>$rclocalfile
	echo "sleep 5">>$rclocalfile
	echo "sudo service isc-dhcp-server restart">>$rclocalfile
	echo "exit 0">>$rclocalfile

	sudo iptables -F
	sudo iptables -t nat -A POSTROUTING -o $wired_ext_nic -j MASQUERADE
	sudo iptables -A FORWARD -i $wired_ext_nic -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i br0 -o $wired_ext_nic -j ACCEPT
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
#Change current user Password
echo "Would you like to change current user's password?"
echo "1) Yes"
echo "2) No"
read changepass
if [ $changepass = "1" ];
then
	passwd
fi

##########################################################################################################################################################
#Change sudo Password
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

	echo "Done removing unnecessary packages and  updates"
	#sudo reboot
fi

##########################################################################################################################################################
#Clear logs
echo "Would you like to clear logs and clean up system?"
echo "1) Yes"
echo "2) No"
read clearlogs
if [ $clearlogs = "1" ];
then
	sudo apt-get autoremove && sudo apt-get clean && sudo apt-get autoclean
	for logs in `find /var/log -type f`; do > $logs; done
	sudo cat /dev/null > .bash_history
	history -cw
	
fi


##########################################################################################################################################################
#Finish up
echo "Config complete, would you like to reboot?"
echo "1) Yes"
echo "2) No"
read reboot
if [ $reboot = "1" ];
then
	#echo "Updating and Upgrading Packages"
	#sudo apt-get update
	#sudo apt-get upgrade
	echo "Rebooting now!"
	sudo reboot
else
	exit 0 
fi
