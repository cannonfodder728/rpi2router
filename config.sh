#!/bin/bash

hostapdconffile="/etc/hostapd/hostapd.conf"
interfaces_file="/etc/network/interfaces"
dhcpconffile="/etc/dhcp/dhcpd.conf"
rclocalfile="/etc/rc.local"
now=$(date +"%m_%d_%Y_%H_%M_%S")

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

##########################################################################################################################################################
#Install required utils

apt-get -y update

pkgs="
	
	raspi-config
	rpi-update
	htop
	screen
	iperf
	libnl-route-3-200
	libnl-genl-3-200
	libnl-3-200
	libncurses5-dev
	lshw
	bridge-utils
	libnl-dev
	libssl-dev
	file
	build-essential
	curl
	usbutils
	iptables
	nano
	wireless-tools
	iw
	git
	unzip
	dkms
	bc
	python
	ethtool
	
	"
	
	# Install packages packages
for i in $pkgs; do
	type $i &> /dev/null && echo found $i || echo didnt find $i &&  apt-get -y install $i	
done

echo "Adding ssh file to boot to ensure SSH is open"
touch /boot/ssh


##########################################################################################################################################################
#Resize SD CARD file
echo "Resize SD Card? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read -r input
if [ $input = "1" ];
then
	apt-get -y install raspi-config
	raspi-config
fi

##########################################################################################################################################################
#Set Time
echo "Set Time? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
	 apt-get -y install dpkg-reconfigure
	 dpkg-reconfigure tzdata
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
        	echo "blacklist brcmfmac" >> /etc/modprobe.d/brcmfmac.conf
		rmmod brcmfmac
		echo "Disabled Onboard Wifi"
	fi
	
	#Enable Serial Console
	echo "Enable Serial Console? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"
	read input
	if [ $input = "1" ];
	then
        	 echo "enable_uart=1" >> /boot/config.txt
	fi
	
	#Disable Bluetooth
	echo "Disable bluetooth? (Enter 1 or 2 or any other key to skip)"
	echo "1) Yes"
	echo "2) No"

	read input
	if [ $input = "1" ];
	then
		echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt
	fi
fi


############################################################################################################################################################
#change hostname
echo "Change hostname? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
    	echo "Enter new hostname"
	read hostname
	echo $hostname > /etc/hostname
fi

############################################################################################################################################################
#Install WiFi Drivers
echo "Attempt to install Wifi Drivers? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
	
read input
if [ $input = "1" ];
then
     	wget http://www.fars-robotics.net/install-wifi -O /usr/bin/install-wifi
     	chmod +x /usr/bin/install-wifi
     	install-wifi
	sleep 3
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
	wget https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source

	# Make it executable
	chmod +x /usr/bin/rpi-source

	# Tell the update mechanism that this is the latest version of the script
	/usr/bin/rpi-source -q --tag-update

	# Get the kernel files thingies.
	rpi-source
fi

##########################################################################################################################################################
#List Network Interfaces and input wired and wireless nic device names
echo "The following interfaces were found on your Pi"
for f in /sys/class/net/*; do
    dev=$(basename $f)
    driver=$(readlink $f/device/driver/module)
    if [ $driver ]; then
        driver=$(basename $driver)
    fi
    addr=$(cat $f/address)
    operstate=$(cat $f/operstate)
    printf "%10s [%s]: %10s (%s)\n" "$dev" "$addr" "$driver" "$operstate"
done

echo "Enter Wired interface which will be connected to Internet"
read wired_ext_nic

echo "Enter WLAN interface which will be used for  Internal Network"
read wlan_int_nic

echo "Enter Wired interface which will be used for Internal Network"
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
	cp $interfaces_file /etc/network/interfaces$now
	rm -f $interfaces_file
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
echo "Configure Internal Interface? (Note: Hostapd entry will point to /etc/hostapd/hostapd.conf) (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"

read input
if [ $input = "1" ];
then
	echo "Config Bridge Interface"
	echo "Enter Static IP Address for internal network"
	read intstaticip
	
	echo "Enter Netmask for internal network"
	read intnetmask
	
	intnetbroadcast=$(awk -F"." '{print $1"."$2"."$3".0"}'<<<$inetstaticip)
    	echo "Using $intnetbroadcast for subnet"

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


##########################################################################################################################################################
#configure external wired nic appropriately
echo "How will external (Internet/WAN) connection be configured? (Enter 1 or 2 or any other key to skip)"
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
		hostapdconffile="/etc/hostapd/hostapd.conf"
		echo "Hostapd Config file variable not setting using $hostapdconffile"
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
	
	 apt-get -y install hostapd
	
	
	#Create Hostapd.conf file
	cp $hostapdconffile /etc/hostapd/hostapd.conf.$now
	echo "driver=nl80211">>$hostapdconffile
	echo "#logger_syslog=-1">>$hostapdconffile
	echo "#logger_syslog_level=2">>$hostapdconffile
	echo "#logger_stdout=-1">>$hostapdconffile
	echo "#logger_stdout_level=2">>$hostapdconffile
	echo "interface=$wlan_int_nic">>$hostapdconffile
	echo "bridge=br0">>$hostapdconffile

	echo "ssid=$SSID">>$hostapdconffile
	echo "macaddr_acl=0">>$hostapdconffile
	echo "auth_algs=1">>$hostapdconffile
	echo "ignore_broadcast_ssid=0">>$hostapdconffile
	echo "wpa=2">>$hostapdconffile
	echo "wpa_passphrase=$wifipass">>$hostapdconffile
	echo "wpa_key_mgmt=WPA-PSK">>$hostapdconffile
	echo "wpa_pairwise=CCMP">>$hostapdconffile
	echo "require_ht=1">>$hostapdconffile
	echo "wmm_enabled=1">>$hostapdconffile
	echo "ieee80211n=1">>$hostapdconffile
	
	if [ $fiveg = "1" ];
	then 
		 echo "ieee80211ac=1">>$hostapdconffile
		 echo "channel=36">>$hostapdconffile
		 echo "hw_mode=a">>$hostapdconffile
		 echo "require_vht=1">>$hostapdconffile
		 echo "vht_oper_chwidth=0">>$hostapdconffile
		 echo "#vht_capab=[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1]">>$hostapdconffile
		 echo "#vht_oper_centr_freq_seg0_idx=62">>$hostapdconffile
	else
		 echo "channel=6">>$hostapdconffile
		 echo "#ht_capab=[HT40-][SHORT-GI-40][DSSS_CCK-40]">>$hostapdconffile
		 echo "ht_capab=[HT40]">>$hostapdconffile
		 echo "hw_mode=g">>$hostapdconffile
		 echo "#noscan=1">>$hostapdconffile
	fi
	echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"">>/etc/default/hostapd
	
	echo "Done configuring hostapd.conf file"

	update-rc.d hostapd defaults &&  update-rc.d hostapd enable && service hostapd start
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

	#echo "Please enter DHCP Server subnet (usually subnet for WLAN NIC)"
	#read subnet

 	#subnet=`echo $intstaticip | cut -d . -f 1-3`
        #subnet=$subnet".0"
	#echo "Using $subnet as subnet"

	#echo "Please enter starting IP of DHCP range"
	#read startip
	#startip=`echo $intstaticip | cut -d . -f 1-3`
        #startip=$startip".10"
	#echo "Using $startip as stating ip"

	#echo "Please enter ending IP of DHCP range"
	#read endip
       	#endip=`echo $intstaticip | cut -d . -f 1-3`
        #endip=$endip".50"
        #echo "Using $endip as ending ip"


	#echo "Please broadcast IP"
	#read broadcastip

       	subnet=$(awk -F"." '{print $1"."$2"."$3".0"}'<<<$inetstaticip)
        echo " using $subnet for subnet"

        startip=$(awk -F"." '{print $1"."$2"."$3".10"}'<<<$inetstaticip)
        echo "Using $startip as stating ip"

        endip=$(awk -F"." '{print $1"."$2"."$3".50"}'<<<$inetstaticip)
        echo "Using $endip as ending ip"


	echo "Installing DHCP Server for DHCP and DNS Services on WLAN"
	apt-get -y install isc-dhcp-server
	cp $dhcpconffile /etc/dhcp/dhcpd.conf.$now
	rm -f $dhcpconffile
	echo "subnet $subnet netmask 255.255.255.0">>$dhcpconffile

	echo "{">>$dhcpconffile
	echo "range $startip $endip;">>$dhcpconffile
	echo "option broadcast-address $intnetbroadcast;">>$dhcpconffile
	echo "option routers $intstaticip;">>$dhcpconffile
	echo "default-lease-time 600;">>$dhcpconffile
	echo "max-lease-time 7200;">>$dhcpconffile
	echo "option domain-name-servers 8.8.8.8, 8.8.4.4;">>$dhcpconffile
	echo "}">>$dhcpconffile
	echo "authoritative;">>$dhcpconffile

	cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server$now
	rm -f /etc/default/isc-dhcp-server
	echo "INTERFACES=br0">>/etc/default/isc-dhcp-server
	update-rc.d isc-dhcp-server enable
	service isc-dhcp-server start
fi

##########################################################################################################################################################
#Configure sshd including new port

echo "Would you like to change default SSH port and reconfigure SSH keys? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read changesshport
if [ $changesshport = "1" ]; then
	echo "Please enter on which port you would like SSH Server to listen?"
	read sshport
	echo "Port $sshport" >> /etc/ssh/sshd_config
	echo "PermitRootLogin no">> /etc/ssh/sshd_config 
	echo "Protocol 2">> /etc/ssh/sshd_config
	echo "IgnoreRhosts yes">> /etc/ssh/sshd_config
	echo "HostbasedAuthentication no">> /etc/ssh/sshd_config
	echo "PermitEmptyPasswords no">> /etc/ssh/sshd_config
	echo "Changed SSH Port"
	echo "Reconfiguring OpenSSH Keys"

	rm /etc/ssh/ssh_host_*
	dpkg-reconfigure openssh-server
fi

##########################################################################################################################################################
#Configure fail2ban
echo "Would you like to install Fail2Ban? (Enter 1 or 2 or any other key to skip)" 
echo "1) Yes" 
echo "2) No"
read fail2ban
if [ $fail2ban = "1" ];
then
        apt-get -y install fail2ban
        echo "installed fail2ban"
        # copy the example configuration file and make it live
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        if [ -z "$sshport" ];
        then
                sshportfail2ban=22
        else
                sshportfail2ban=$sshport
        fi
        
	#echo $sshportfail2ban
        echo "using $sshportfail2ban as ssh port"
        echo "[ssh]" >> /etc/fail2ban/jail.local
        echo "enabled = true" >> /etc/fail2ban/jail.local
        echo "port = $sshportfail2ban" >> /etc/fail2ban/jail.local
        echo "filter = sshd" >> /etc/fail2ban/jail.local
        echo "logpath = /var/log/auth.log" >> /etc/fail2ban/jail.local
        echo "banaction = iptables-allports ; ban retrys on any port" >> /etc/fail2ban/jail.local
        echo "bantime = 6000 ; ip address is banned for 10 minutes" >> /etc/fail2ban/jail.local
        echo "maxretry = 10 ; allow the ip address retry a max of 10 times" >> /etc/fail2ban/jail.local
fi
##########################################################################################################################################################
#configure firewall
echo "Configure Firewall? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ];
then
	echo "setup firewall rules appropriately and startup script"
	sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
	
	cp $rclocalfile /etc/rc.local$now
	rm -f $rclocalfile
	touch $rclocalfile 
	sed -i 's/#exit 0/#exit 0/g' $rclocalfile
	echo " ifdown $wired_ext_nic">>$rclocalfile
	echo " ifup $wired_ext_nic">>$rclocalfile
	
	echo "sleep 3">>$rclocalfile
	echo " ifdown br0">>$rclocalfile
	echo " ifup br0">>$rclocalfile
	echo "sleep 3">>$rclocalfile
    	echo " ifconfig $wlan_int_nic | grep -q $wlan_int_nic && echo 'found $wlan_int_nic nothing to do'> /dev/kmsg ||  /usr/bin/install-wifi ">>$rclocalfile
	
	echo " hostapd -B /etc/hostapd/hostapd.conf">>$rclocalfile
	echo "sleep 3">>$rclocalfile
	echo " service isc-dhcp-server restart">>$rclocalfile
	echo "exit 0">>$rclocalfile

	iptables -F
	iptables -t nat -A POSTROUTING -o $wired_ext_nic -j MASQUERADE
	iptables -A FORWARD -i $wired_ext_nic -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i br0 -o $wired_ext_nic -j ACCEPT
	iptables -A OUTPUT -p tcp --tcp-flags ALL ALL -j DROP
	iptables -A OUTPUT -p tcp --tcp-flags ALL ACK,RST,SYN,FIN -j DROP
	iptables -A OUTPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
	iptables -A OUTPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
	iptables -A OUTPUT -p tcp --tcp-flags ALL NONE -j DROP
	iptables -A OUTPUT -i $wired_ext_nic -p icmp --icmp-type echo-request -j DROP
	rm -f /etc/iptables.ipv4.nat
	sh -c "iptables-save > /etc/iptables.ipv4.nat"

	# sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

	echo "up iptables-restore < /etc/iptables.ipv4.nat">> /etc/network/interfaces

	echo "Done setting up startup script with Firewall Rules"
fi

##########################################################################################################################################################
#Change current user Password
echo "Would you like to change current user's password? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read changepass
if [ $changepass = "1" ];
then
	passwd
fi

##########################################################################################################################################################
#Change  Password
echo "Would you like to change root password? (Enter 1 or 2 or any other key to skip)"
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
#Add User
echo "Would you like to a new user with  privileges? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read input

if [ $input = "1" ]; then
	echo "Enter Username of new user"
	read user
	apt-get install 
	echo "adding user $user"
	adduser $user 
	adduser $user 
	usermod -a -G  $user
fi

##########################################################################################################################################################
#Disable root account
echo "Disable root account? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read input
if [ $input = "1" ]; then
	echo "disabling root user"
       	passwd -dl root
fi

##########################################################################################################################################################
#Remove unnecessary packages
echo "Remove Unnecessary packages? (Enter 1 or 2) (Enter 1 or 2 or any other key to skip)"
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
		 apt-get -y remove --purge $i
	done

	# Remove automatically installed dependency packages
	 apt-get -y autoremove

	echo "Done removing unnecessary packages and  updates"
	# reboot
fi

##########################################################################################################################################################
#Clear logs
echo "Would you like to clear logs and clean up system? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read clearlogs
if [ $clearlogs = "1" ];
then
	apt-get autoremove &&  apt-get clean &&  apt-get autoclean
	for logs in `find /var/log -type f`; do > $logs; done
	cat /dev/null > .bash_history
	history -cw
fi

##########################################################################################################################################################
#Finish up
echo "Config complete, would you like to reboot? (Enter 1 or 2 or any other key to skip)"
echo "1) Yes"
echo "2) No"
read reboot
if [ $reboot = "1" ];
then
	#echo "Updating and Upgrading Packages"
	# apt-get update
	# apt-get upgrade
	echo "Rebooting now!"
	reboot
else
	exit 0 
fi
