#!/bin/bash

hostapdconffile="/etc/hostapd/hostapd.conf"
interfaces_file="/etc/network/interfaces"
dhcpconffile="/etc/dhcp/dhcpd.conf"
rclocalfile="/etc/rc.local"
logfile="routerconfig.log"
rm -f $logfile
now=$(date +"%m_%d_%Y_%H_%M_%S")

count=0
if ! [ $(id -u) = 0 ]; then
   echo "Please execute as root!"
   exit 1
fi

function valid_ip()
{
    local  IPA1=$1
    local  stat=1

    if [[ $IPA1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
    then
        OIFS=$IFS

   IFS='.'             #read man, you will understand, this is internal field separator; which is set as '.' 
        ip=($ip)       # IP value is saved as array
        IFS=$OIFS      #setting IFS back to its original value;

        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
           && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]  # It's testing if any part of IP is more than 255
        stat=$? #If any part of IP as tested above is more than 255 stat will have a non zero value
    fi
    return $stat # as expected returning
}
#echo "testig 1.1.1.1"
#valid_ip "1.1.1.1"
#valid_ip "1.1.1.1"
#if [ $? -eq 0 ];
#then
#echo "good ip"
#else
#echo "not ip"
#fi

#Install required utils
function exitCode()
{
	#read -p "Press enter to continue"
	OUT=$?
	if [ $OUT -eq 0 ];then
		whiptail --title "Done" --msgbox "Successfully completed $1." 8 78   		
		echo "$now Successfully Completed $1" | tee -a $logfile
	else
   		whiptail --title "Done" --msgbox "Failed $1." 8 78   
		#cp /etc/network/interfaces.backup /etc/network/interfaces
		echo "$now Failed $1" | tee -a $logfile
		if (whiptail --title "$1" --yesno "$1 failed, do you want to exit?" 8 78); then
			exit
		fi
		
	fi
}

echo "$now Updating System...Standby" | tee -a $logfile

apt-get -y update
apt-get -y upgrade
exitCode "System Update"

echo "$now Attempting dist upgrade" | tee -a $logfile
apt-get -y dist-upgrade
exitCode "Dist Upgrade"


echo "$now installing needed tools" | tee -a $logfile
apt-get -y install raspi-config rpi-update debconf htop bc libssl-dev raspberrypi-kernel-headers bison screen iperf libnl-route-3-200 libnl-genl-3-200 libnl-3-200 libnl-3-dev libnl-genl-3-dev libncurses5-dev lshw bridge-utils libnl-dev libssl-dev file build-essential	curl usbutils iptables nano wireless-tools iw git unzip dkms bc python ethtool
sudo apt install 

exitCode "Installed Needed Tools"


apt-get -y autoremove

echo "$now Adding ssh file to boot to ensure SSH is open" | tee -a $logfile
touch /boot/ssh
exitCode "Creating SSH file"

echo "$now Done. Launching Menu" | tee -a $logfile



function setInterfaces()
{
	if [ -z "$SSID" ];
	then
		SSID="wifi"
	    whiptail --title "SSID Not Set" --msgbox "SSID  not set, using $SSID." 8 78   
		echo "$now SSID variable not seting using $SSID"  | tee -a $logfile
	fi
	if [ -z "$wlan_int_nic" ];
	then
		wlan_int_nic="wlan0"
	    whiptail --title "WLAN NIC Not Set" --msgbox "WLAN Internal NIC not set, using $wlan_int_nic." 8 78   
		echo "$now wlan nic variable not seting using $wlan_int_nic" | tee -a $logfile
	fi
	if [ -z "$wired_ext_nic" ];
	then
		wired_ext_nic="eth0"
	    whiptail --title "External NIC Not Set" --msgbox "External Wired NIC not set, using $wired_ext_nic." 8 78   
		echo "$now wlan nic variable not seting using $wired_ext_nic" | tee -a $logfile
	fi
	if [ -z "$wired_int_nic" ];
	then
		wired_int_nic="eth1"
	    whiptail --title "Internal NIC Not Set" --msgbox "Internal Wired NIC not set, using $wired_int_nic." 8 78   
		echo "$now wlan nic variable not seting using $wired_int_nic" | tee -a $logfile
	fi
}
function getInterfaces ()
{
	for f in /sys/class/net/*; do
	    	dev=$(basename $f)
	    	driver=$(readlink $f/device/driver/module)
	    	if [ $driver ]; then
			driver=$(basename $driver)
	    	fi
	    	addr=$(cat $f/address)
	    	operstate=$(cat $f/operstate)


		ipaddr=$(ifconfig $dev | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
		count=$((count+1))
		whiptailstr=$whiptailstr" "$dev" "$ipaddr,$operstate,$driver" "
		
	done

	var=$(whiptail --title "Found $count interfaces $1" --menu "Select $1 " 20 78 $count $whiptailstr 3>&1 1>&2 2>&3)
	echo $var
	#echo "$now got following interfaces $var" | tee -a $logfile
}

function configSSH ()
{
    if (whiptail --title "Config SSH" --yesno "Do you want to change default ssh port?" 8 78); then
	    sshport=$(whiptail --inputbox "Enter SSH Port" 8 78 19810 --title "Change default SSH Port" 3>&1 1>&2 2>&3)
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

	    exitCode "Config SSH"
	fi

}

function setTime ()
{
	if (whiptail --title "Set Time" --yesno "Do you want to set the time ?" 8 78); then
	
		echo "$now Attempting to set time" | tee -a $logfile
		dpkg-reconfigure tzdata
		exitCode "Set Time"
	fi
    
}


function disableRadios ()
{

	if (whiptail --title "Disable Onboard Wifi" --yesno "Do want to disable onboard Wifi?" 8 78); then
		echo "$now Attempting to Disable onboard WiFi and Bluetooth" | tee -a $logfile

		#Check if we're on RPI3
		rpi3=$(cat /proc/device-tree/model | grep -ie 'Raspberry Pi 3' | wc -l)
		if [ $rpi3 -ge 1 ];
		then
			echo "dtoverlay=pi3-disable-wifi" >> /boot/config.txt
		fi
		
		#Check if we're on RPI4
		rpi4=$(cat /proc/device-tree/model | grep -ie 'Raspberry Pi 4' | wc -l)
		if [ $rpi4 -ge 1 ];
		then
			echo "dtoverlay=disable-wifi" >> /boot/config.txt
		fi
		
		#Remove onboard Wifi module
		rmmod brcmfmac
		exitCode "Disabled Onboard Wifi"
	fi
	if (whiptail --title "Disable Onboard Bluetooth" --yesno "Do want to disable onboard Bluetooth?" 8 78); then
	
		#Disable Bluetooth
		echo "dtoverlay=disable-bt" >> /boot/config.txt
		systemctl disable hciuart.service
		systemctl disable bluealsa.service
		systemctl disable bluetooth.service
			
		exitCode "Disabled Onboard Bluetooth"		
	fi
    # exitCode "Enable Serial Console"
}

function enableSerial ()
{
	if (whiptail --title "Enable Serial Console" --yesno "Do you want to enable serial console ?" 8 78); then
		#Enable Serial Console
		echo "enable_uart=1" >> /boot/config.txt
		exitCode "Enable Serial Console"			
		
 	fi
}


function changeHostname ()
{
    if (whiptail --title "Change HostName" --yesno "Do you want to change the hostname?" 8 78); then
		echo -e "Enter hostname:"
		read hostname
		echo "$now New hostname $hostname" | tee -a $logfile
		echo $hostname > /etc/hostname
		exitCode "Change HostName"
	fi

}

function configWiFi ()
{
    if (whiptail --title "Install Wifi Drivers" --yesno "Do you want to install WiFi drivers?" 8 78); then
	   	echo "$now Attempting to install WiFi drivers" | tee -a $logfile

		wget http://downloads.fars-robotics.net/wifi-drivers/install-wifi -O /usr/bin/install-wifi
	   	chmod +x /usr/bin/install-wifi
	   	install-wifi
		sleep 3
		exitCode "Install Wifi"
		
	fi

}

function configFail2Ban ()
{
	if (whiptail --title "Install Fail2Ban" --yesno "Do you want to install Fail2Ban?" 8 78); then
		apt-get -y remove fail2ban
		apt-get -y install fail2ban
		echo "$now Attempting to install fail2ban" | tee -a $logfile
		
		# copy the example configuration file and make it live
		cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
		if [ -z "$sshport" ];
		then
		        sshportfail2ban=22
		else
		        sshportfail2ban=$sshport
		fi
		
		#echo $sshportfail2ban
		echo "$now using $sshportfail2ban as ssh port" | tee -a $logfile
		echo "[ssh]" >> /etc/fail2ban/jail.local
		echo "enabled = true" >> /etc/fail2ban/jail.local
		echo "port = $sshportfail2ban" >> /etc/fail2ban/jail.local
		echo "filter = sshd" >> /etc/fail2ban/jail.local
		echo "logpath = /var/log/auth.log" >> /etc/fail2ban/jail.local
		echo "banaction = iptables-allports ; ban retrys on any port" >> /etc/fail2ban/jail.local
		echo "bantime = 6000 ; ip address is banned for 10 minutes" >> /etc/fail2ban/jail.local
		echo "maxretry = 10 ; allow the ip address retry a max of 10 times" >> /etc/fail2ban/jail.local
		exitCode "Install Fail2Ban"
 	fi
}

function changeCurrUserPass ()
{

    if (whiptail --title "Change current user password" --yesno "Do you want to change current user ($SUDO_USER) password?" 8 78); then
		echo "$now Attempting to change current user ($SUDO_USER) password" | tee -a $logfile
		passwd $SUDO_USER
       	exitCode "Change current user password"
	fi
}


function changeRootPass ()
{
   	if (whiptail --title "Root password" --yesno "Do you want to change root password?" 8 78); then
		#myvariable=$USER	#if [ $input = "1" ];	
		#echo "Enter new password"
		#S1=$(whiptail --passwordbox "Enter new root password" 8 78 --title "Change Root Password" 3>&1 1>&2 2>&3)
		#read S1
		#echo "Re-Enter new password"
		#S2=$(whiptail --passwordbox "Re-enter new root password" 8 78 --title "Change Root Password" 3>&1 1>&2 2>&3)
		#read  S2#if [ $input = "1" ];
		#if [ "$S1" = "$S2" ];
	    #	then
		echo "$now Attempting change root password" | tee -a $logfile

		sudo -i passwd
		exitCode "Change root pass"
		
	fi
}

function disableRoot ()
{
   	if (whiptail --title "Disable Root Account" --yesno "Do you want to disable root account?" 8 78); then
		echo "$now Disabling root account" | tee -a $logfile
		passwd -dl root
		exitCode "Disable root account"
		#clearLogs
	
	fi
}

function configFirewall ()
{
	if (whiptail --title "Configure Firewall" --yesno "Do you want to configure firewall?" 8 78); then
		echo "$now Setting up firewall rules appropriately and startup script" | tee -a $logfile
		sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
		
		cp $rclocalfile /etc/rc.local.backup
		rm -f $rclocalfile
		touch $rclocalfile 
		sed -i 's/#exit 0/#exit 0/g' $rclocalfile
		echo " ifdown $wired_ext_nic">>$rclocalfile
		echo " ifup $wired_ext_nic">>$rclocalfile
		
		echo "sleep 5">>$rclocalfile
		echo " ifdown br0">>$rclocalfile
		echo " ifup br0">>$rclocalfile
		echo "sleep 5">>$rclocalfile
	    echo " ifconfig $wlan_int_nic | grep -q $wlan_int_nic && echo 'found $wlan_int_nic nothing to do'> /dev/kmsg ||  /usr/bin/install-wifi ">>$rclocalfile
		
		
		echo "hostapd -B /etc/hostapd/hostapd.conf">>$rclocalfile
		echo "sleep 5">>$rclocalfile
		echo "systemctl restart isc-dhcp-server.service">>$rclocalfile
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
		iptables -A INPUT -i $wired_ext_nic -p icmp --icmp-type echo-request -j DROP
		rm -f /etc/iptables.ipv4.nat
		sh -c "iptables-save > /etc/iptables.ipv4.nat"

		# sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

		echo "up iptables-restore < /etc/iptables.ipv4.nat">> $interfaces_file

		#echo "Done setting up startup script with Firewall Rules"
		exitCode "Configure Firewall"
	fi
	#changeCurrUserPass
}

function selectInterfaces ()
{
	
	wired_ext_nic=$(getInterfaces "Wired External Interface")
	echo $now $wired_ext_nic" selected as Wired External Interface" | tee -a $logfile

	wlan_int_nic=$(getInterfaces "WLAN Interface")
	echo $now $wlan_int_nic" selected as WLAN Interface" | tee -a $logfile
	#wired_int_nic=""
	#echo $count
	#if [ $count -gt 3 ];
	#then

		wired_int_nic=$(getInterfaces "Wired Internal Interface")
	echo $now $wired_int_nic" selected as Wired Interface" | tee -a $logfile
	#fi
	exitCode "Config Interfaces"
	#configBridge
}
function cleanNetworking ()
{
	if ethtool br0 | grep -q "Link detected: yes"; then
		echo "$now found br0 up...deleting" | tee -a $logfile
		ifdown br0
		brctl delbr br0
	else
		echo "$now Did NOT find br0 up" | tee -a $logfile
	fi
	
	echo "$now Attempting backup interfaces file" | tee -a $logfile
	cp $interfaces_file /etc/network/interfaces.backup
	rm -f $interfaces_file
	echo "$now Backed up and deleted existing interfaces file" | tee -a $logfile

}
function configBridge ()
{
	
	#echo "Config Bridge Interface"
	#echo "Enter Static IP Address for internal network"
	echo "$now Attempting to config bridge" | tee -a $logfile

	intstaticip=$(whiptail --inputbox "Enter Static IP Address for internal interface" 8 78 192.168.10.1 --title "Config Bridge/Internal Interface" 3>&1 1>&2 2>&3)
	
	
	#valid_ip $intstaticip
	#if [ $? -eq 0 ];
	#then
	#	echo "$now valid ip entered $intstaticip for internal network static IP" | tee -a $logfile
	#else
	#	whiptail --title "Invalid IP entered" --msgbox "Not a valid IP.  Please redo" 8 78
	#	configBridge
	#fi

	intnetmask=$(whiptail --inputbox "Enter Netmask for internal interface" 8 78 255.255.255.0 --title "Config Bridge/Internal Interface" 3>&1 1>&2 2>&3)
	
	#valid_ip $intnetmask
	#if [ $? -eq 0 ];
	#then
	#	echo "$now valid ip entered $intnetmask for internal network netmask" | tee -a $logfile
	#else
	#	whiptail --title "Invalid IP entered" --msgbox "Not a valid IP.  Please redo" 8 78
	#	configBridge
	#fi

	
	intnetbroadcast=$(awk -F"." '{print $1"."$2"."$3".0"}'<<<$intstaticip)
    
	echo "Using $intnetbroadcast for subnet" | tee -a $logfile
	
	#whiptail --title "Config Bridge Interface" --msgbox "Using $intnetbroadcast for subnet" 8 78
		
	echo "auto lo">>$interfaces_file
	echo "iface lo inet loopback">>$interfaces_file	
	
	echo "iface $wlan_int_nic inet manual">>$interfaces_file
	echo "iface $wired_int_nic inet manual">>$interfaces_file
	
	echo "auto br0">>$interfaces_file	
	echo "iface br0 inet static">>$interfaces_file
	#if [ -z "$wired_int_nic" ];
	#then
	#	echo "bridge_ports $wlan_int_nic">>$interfaces_file

	#else
		echo "bridge_ports $wlan_int_nic $wired_int_nic">>$interfaces_file
	#fi
	echo "address $intstaticip">>$interfaces_file
	echo "broadcast $intnetbroadcast">>$interfaces_file
	echo "netmask $intnetmask">>$interfaces_file
	
	
	#ifup --no-act br0
	exitCode "Config Bridge"

	#configExternalInt
}

function configExternalInt ()
{

	CHOICE=$(whiptail --title "Configure External Interface" --radiolist \
	"How will external interface be configured?" 15 60 4 \
	"static" "Enter IP info manually" OFF \
	"dhcp" "IP automically assigned by ISP" ON 3>&1 1>&2 2>&3)

	
	if [ $CHOICE = "static" ];
	then
		wiredstaticip=$(whiptail --inputbox "Enter Static IP Address for External Interface" 8 78 10.0.0.2 --title "Config External Interface" 3>&1 1>&2 2>&3)
		wirednetmask=$(whiptail --inputbox "Enter Netmask for External Interface" 8 78 255.0.0.0 --title "Config External Interface" 3>&1 1>&2 2>&3)
		wiredgateway=$(whiptail --inputbox "Enter Gateway for External Interface" 8 78 10.0.0.1 --title "Config External Interface" 3>&1 1>&2 2>&3)
		wireddnsserver=$(whiptail --inputbox "Enter DNS Server for External Interface" 8 78 8.8.8.8 --title "Config External Interface" 3>&1 1>&2 2>&3)			
		
		echo "auto $wired_ext_nic">>$interfaces_file
		echo "iface $wired_ext_nic inet static">>$interfaces_file
		echo "address $wiredstaticip">>$interfaces_file
		echo "netmask $wirednetmask">>$interfaces_file
		echo "gateway $wiredgateway">>$interfaces_file
		echo "dns-nameservers $wireddnsserver">>$interfaces_file
	else
		echo "$now Config wired external interface using DHCP" | tee -a $logfile
		echo "auto $wired_ext_nic">>$interfaces_file
		echo "iface $wired_ext_nic inet dhcp">>$interfaces_file
			
	fi	
	#ifup --no-act $wired_ext_nic
	exitCode "Config External Interface"
}

function configHostapd ()
{
	wpa_psk=''
	echo "$now Installing HostAPD and setting config file" | tee -a $logfile
	SSID=$(whiptail --inputbox "Enter SSID for Wireless Network" 8 78 mywifi --title "Config WLAN Interface" 3>&1 1>&2 2>&3)
	
	S1=$(whiptail --passwordbox "Enter WiFi password" 8 78 --title "Config WLAN Interface" 3>&1 1>&2 2>&3)
	S2=$(whiptail --passwordbox "Re-enter WiFi password" 8 78 --title "Config WLAN Interface" 3>&1 1>&2 2>&3)
	
	if [ ${#S1} -lt 8 ]; 
	then 
        whiptail --title "Password Length " --msgbox "Wifi password must be at least 8 characters. Hit OK to continue." 8 78
		configHostapd

	fi

	if [ "$S1" = "$S2" ];
	then
		whiptail --title "Config WLAN Interface" --msgbox "Passwords match. Hit OK to continue." 8 78
	else
		whiptail --title "Config WLAN Interface" --msgbox "Passwords DONT match. Hit OK to continue." 8 78
		configHostapd
	fi
	#exitCode "WiFi Password"

	if (whiptail --title "Configure WLAN Interface" --yesno "Configure Wireless connection (Hostapd will be installed and configured)?" 8 78); then
		fiveg=0
		if (whiptail --title "Configure WLAN Interface" --yesno "Configure Hostapd for 5Ghz?" 8 78); then

			fiveg="1"
		fi

		cp $hostapdconffile /etc/hostapd/hostapd.conf.backup
		rm -f $hostapdconffile
		apt-get -y remove hostapd	
		apt-get -y install hostapd
		
		
		#Create Hostapd.conf file
		echo "driver=nl80211">$hostapdconffile
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
		wpa_psk=$(wpa_passphrase $SSID $S1 |grep -i '\bpsk=\b' | grep -o '[0-9,a-f]\+')
		echo "$now Calculated PSK $wpa_psk based on passphrase" | tee -a $logfile
		
		echo "wpa_psk=$wpa_psk">>$hostapdconffile
		echo "wpa_key_mgmt=WPA-PSK">>$hostapdconffile
		echo "wpa_pairwise=CCMP">>$hostapdconffile
		echo "require_ht=1">>$hostapdconffile
		echo "wmm_enabled=1">>$hostapdconffile
		echo "country_code=US">>$hostapdconffile
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
		
		echo "$now Done configuring hostapd.conf file" | tee -a $logfile
		echo "$now Setting Regulatory Domain as US (helps with freeing up channels to Access Point)" | tee -a $logfile
		iw reg set US
		
		update-rc.d hostapd defaults 
		sleep 3
		update-rc.d hostapd enable 
		systemctl unmask hostapd.service
		sleep 3
		#systemctl start hostapd.service
		exitCode "Install hostapd"
		echo "$now Done configuring hostapd" | tee -a $logfile
	fi
	#configDHCP
}

function configDHCP ()
{
	
	if (whiptail --title "Install DHCP Server" --yesno "Configure DHCP (ISC DHCP Server will be installed and configured)?" 8 78); then
		subnet=$(awk -F"." '{print $1"."$2"."$3".0"}'<<<$intstaticip)
		echo "$now Using $subnet for DHCP subnet" | tee -a $logfile

		startip=$(awk -F"." '{print $1"."$2"."$3".10"}'<<<$intstaticip)
		echo "$now Using $startip as starting DHCP ip" | tee -a $logfile

		endip=$(awk -F"." '{print $1"."$2"."$3".50"}'<<<$intstaticip)
		echo "$now Using $endip as ending DHCP ip" | tee -a $logfile


		echo "$now Installing DHCP Server for DHCP Services on WLAN"  | tee -a $logfile
		cp $dhcpconffile /etc/dhcp/dhcpd.conf.backup
		rm -f $dhcpconffile
		#ifup br0
    
		apt-get -y remove isc-dhcp-server
		sleep 3
		apt-get -y install isc-dhcp-server
		sleep 3
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

		cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.backup
		rm -f /etc/default/isc-dhcp-server
		echo "INTERFACESv4=br0">>/etc/default/isc-dhcp-server

		update-rc.d isc-dhcp-server defaults 
		sleep 3
		update-rc.d isc-dhcp-server enable
		sleep 3
		#systemctl start isc-dhcp-server.service
		exitCode "Install DHCP Server"
	fi
	#configSSH
}
function clearLogs ()
{
	if (whiptail --title "Clear Logs" --yesno "Would you like to clear logs and clean up system??" 8 78); then
		apt-get autoremove &&  apt-get clean &&  apt-get autoclean
		for logs in `find /var/log -type f`; do > $logs; done
		cat /dev/null > .bash_history
		history -cw
		exitCode "Clear Logs"
	fi

}

function restart ()
{

	if (whiptail --title "Reboot" --yesno "Would you like to reboot?" 8 78); then
		echo "Rebooting now!"
		reboot
	else
		mainMenu	
	fi

}

function mainMenu {

	CHOICE=$(
	whiptail --title "Configure Router" --menu "Make your choice" 16 100 10 \
		"0)" "Configuration Wizard"   \
		"1)" "Set Time"   \
		"2)" "Disable on Board Radios"  \
		"3)" "Enable Serial Port" \
		"4)" "Change Hostname"\
		"5)" "Install WiFi Drivers"\
		"6)" "Change current user password" \
		"7)" "Change root password" \
		"8)" "Disable root account" \
		"9)" "Clear Logs" \
		"10)" "Restart"  3>&2 2>&1 1>&3\
		"11)" "Exit"
	)

#order setTime->Disable Onboard Radios->Enable Serial->Change Hostname->Install Wifi Drivers->select interfaces->configure interfaces->config bridge->config external->install hostapd->config dhcp->change default ssh port->configure fail2ban->configure firewall->change current user password->change root password->disable root account-> remove unncessary packages->clear logs->reboot	
	case $CHOICE in
		"0)") 
			setTime
			disableRadios
			enableSerial
			changeHostname
			configWiFi
			cleanNetworking
			selectInterfaces
			configBridge
			configExternalInt
			configHostapd
			configDHCP
			configSSH
			configFail2Ban
			configFirewall
			changeCurrUserPass
			changeRootPass
			disableRoot
			clearLogs
			restart
		;;		
		"1)")
			echo 1			
			setTime
			mainMenu
		;;
		"2)")
			echo 2			
			disableRadios
			mainMenu
		;;

		"3)")
		    echo 3			
			enableSerial
			mainMenu
		;;

		"4)")
			echo 4			
			changeHostname
			mainMenu
		;;

		"5)")
			echo 5	
			installWiFi
			mainMenu
		;;

		"6)")
			echo 6
			changeCurrUserPass
			mainMenu
		;;
		"7)")
			echo 7
			changeRootPass
			mainMenu
		;;
		"8)") 
			echo 8
			disableRoot
			mainMenu
		;;
		"9)") 
			echo 9
			clearLogs
			mainMenu
		;;
		"10)") 
			echo 10
			restart
		;;
		"11)")
			echo 11
			exit
		;;
			
	esac
}

#order setTime->Disable Onboard Radios->Enable Serial->Change Hostname->Install Wifi Drivers->select interfaces->configure interfaces->config bridge->config external->install hostapd->config dhcp->change default ssh port->configure fail2ban->configure firewall->change current user password->change root password->disable root account-> remove unncessary packages->clear logs->reboot
mainMenu
#exit
