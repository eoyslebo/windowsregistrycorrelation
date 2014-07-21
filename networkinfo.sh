#!/bin/bash 
###############################################
# Utility to correlate and present registry   #
# networking information in a concise manner  #
# Jacky Fox 2012                              #
###############################################

#############################################
# variable settings			    #
#############################################

regdump_location="/usr/local/bin/regdump.pl"
expert_log_location="network_expert.log" # location of unfiltered output for evidential purposes
log_location="network.log"	 # location of sorted and related usb log
i=0
bslash='\'
crlf="\r\n"
lfcr="\n\r"
tab="\t"
lfcr=`echo -e $lfcr`
linefeed=$'\n'

##########################################
#   command line help function           #
##########################################

# comment out lines for unrequired hives/files

cmd_line_help_func() {

echo "usage : "$0" -S ../hives/system "
echo "	-S (path and name of System hive)  	-S /hives/system"
#echo "	-N (path and name of ntuser.dat hive) 	-N hives/NTUSER.DAT"
#echo "	-A (path and name of setupapi.log file)	-A ../hives/setupapi.dev.log"
echo "	-W (path and name of Software hive)	-W /samples/software"
echo "	-D (default location of hives)		-D xphives"
#echo "	-C (path and name of Security hive)	-C ../hives/SECURITY"
#echo "	-M (path and name of the SAM)		-M ../hives/SAM"
echo "	-E (switch off expert logs)		-E off"
echo "	-L (give explicit path for logs)	-L /logdir"
exit
}

#####################################
# Check current control set number  #
# HKLM\SYSTEM\Select		    #
# Assigns:	$ccs		    #
#####################################

current_control_set_func () {

temp_string=`perl $regdump_location $system_hive_location "Select" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" > $expert_log_location		# first entry so new file ie >
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
then
	ccs="Not available (check SYSTEM hive location)"
else
	ccs=`echo ${temp_string##*Current (REG_DWORD) = 0x}` 	#cut out leading info
	ccs=`echo ${ccs:5:3}` 			    	     	#cut off trailing info
fi
}

#################################################################
# Get the windows version from		      			#
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName #
# Assigns:	$win_ver					#
#		$wpd (vista or Windows 7)			#
#		$win7						#
#################################################################

pull_out_winver_func () {

	temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ] 	 					 
	then
		echo Unable to extract windows version check software hive location
	else
		win_ver=`echo "${temp_string##*ProductName (REG_SZ) = }"` 	
		win_ver=`echo ${win_ver%%$linefeed*}`
	fi
	echo $win_ver | grep -q "Windows 7\|Windows Vista" 	# check if windows is >= Vista, if it is windows
	if [ $? = "0" ]						# hives vary
	then							
		wpd="yes"
	fi
	echo $win_ver | grep -q "Windows 7" 			# check if windows is 7
	if [ $? = "0" ]						
	then							
		win7="yes"
	fi
}

##########################################################################
# Get the network access points (post XP)				 #
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles #
# by getting guids and setting up array of profile data			 # 
# HKLM\Software\Windows\CurrentVersion\Homegroup\NetworkLocations	 #
# Assigns:	$profile_guid[$i]					 #
#		$profile_name[$i]	  				 #
#		$profile_date_created[$i] (date of first connection)	 #
#		$profile_last_con[$i]  	  (date of last connection)	 #
#		$profile_location_[$i] 	  (eg work/home - win7 only)	 #         
##########################################################################

pull_out_network_ap_func () {

# get profile guids

if [ "$wpd" = "yes" ] 	# if it's vista or >
then
	temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location		# append entries to existing file ie >>
	fi
	if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SOFTWARE hive location"
	else
		i=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]			# check to see if string not changed then on last guid
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..\\\{}` 	# cut as far as next guid
			if [ "$temp1" != "$temp_string" ]
			then
				profile_guid[$i]=`echo "{"${temp_string:0:37}` # "{"guid} 
				(( i++ ))
			fi
		done
		((num_profiles=i-1))

# get each profile and populate array

		i=0
		while [ $i -lt $num_profiles ]
		do
			(( i++ ))
			temp_string[$i]=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"$bslash${profile_guid[$i]} -v`
			if [ "$logging" != "off" ]						
			then
				echo "${temp_string[$i]}" >> $expert_log_location # append entries to existing file ie >>
			fi 
		done

# pull out name date created and date last connected from each profile

		i=0
		while [ $i -lt $num_profiles ]
		do
			(( i++ ))
			profile_name[$i]=`echo "${temp_string[$i]##*ProfileName (REG_SZ) = }"`
			profile_name[$i]=`echo ${profile_name[$i]%%$linefeed*}`
			profile_date_created[$i]=`echo ${temp_string[$i]##*DateCreated (REG_BINARY) = }`
			temp=`echo ${profile_date_created[$i]t:0:47} | tr '[:lower:]' '[:upper:]'`
			convert_profile_func
			profile_date_created[$i]=$temp
			profile_last_con[$i]=`echo ${temp_string[$i]##*DateLastConnected (REG_BINARY) = }`
			temp=`echo ${profile_last_con[$i]t:0:47} | tr '[:lower:]' '[:upper:]'`
			convert_profile_func
			profile_last_con[$i]=$temp
		done
	
# get the names of network locations

		if [ "$win7" = "yes" ]	# win 7 only #
		then
			temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows\CurrentVersion\Homegroup\NetworkLocations" -v`
			if [ "$logging" != "off" ]						
			then
				echo "$temp_string" >> $expert_log_location			
			fi
			if [ -z "$temp_string" ] 	 					# if this is empty 
			then
				echo="Check software hive location"
			else
				z=0
				p=$IFS
				IFS=$'\n'
				for eachline in `echo "$temp_string"`				
				do
					if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
					then
						(( z++ ))
						net_loc_name[$z]=${eachline##*..?}
						net_loc_data[$z]=`perl $regdump_location $software_hive_location "Microsoft\Windows\CurrentVersion\Homegroup\NetworkLocations$bslash${net_loc_name[$z]}" -v`
						if [ "$logging" != "off" ]						
						then
							echo "${net_loc_data[$z]}" >> $expert_log_location
						fi
					fi
				done
				IFS=$p
				((num_net_locations=z))
			fi

# check each net location for the profile guids

			i=0
			while [ $i -lt $num_profiles ]
			do
				(( i++ ))
				z=0
				while [ $z -lt $num_net_locations ]
				do
					(( z++ ))
					echo "${net_loc_data[$z]}" | grep -q ${profile_guid[$i]}
					if [ $? = "0" ]
					then
						profile_location[$i]=${net_loc_name[$z]}
						z=$num_net_locations
					fi
				done
			done
		fi
	fi
fi # from if it's vista>
}

#########################################################################################
# get Unmanaged guids & matching MAC addresses & DNS suffix      	    		#
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Unmanaged 	#
# set up array from unmanaged area					    		#
# Assigns:	$unman_guid[$i]						    		#
#		$unman_gate_mac[$i]					    		#
#		$unman_dnssuf[$i]					    		#
# Scroll through unman & profile arrays if guids match then		    		#
# Assigns:	$profile_gate_mac[$i] 					    		#
#		(first 6 chars of MAC compared with ieee db to get WAP manuf 		#
#		$profile_dnssuf[$i]					    		#		
#########################################################################################

get_macadd_func () {

if [ "$wpd" = "yes" ] 	# if it's vista or >
then
temp_string_mac=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Unmanaged" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string_mac" >> $expert_log_location	# append entries to existing file ie >>
fi
if [ -z "$temp_string_mac" ] 				# if this is empty 
then
	echo="Check SOFTWARE hive location"
else
	i=1
	temp1="blank"
	while [ "$temp1" != "$temp_string_mac"  ]	# check to see if string doesn't changed then on last guid
	do
		temp1=$temp_string_mac
		temp_string_mac=`echo ${temp_string_mac#*..?}` 
		if [ "$temp1" != "$temp_string_mac" ]
		then
			unman_id[$i]=`echo ${temp_string_mac%% *}` 			# take id as far as next space
			temp_string_mac[$i]=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Unmanaged"$bslash${unman_id[$i]} -v` 		# get the guid & macadd
			if [ "$logging" != "off" ]						
			then
				echo "${temp_string_mac[$i]}" >> $expert_log_location 	# append entries to file ie >>
			fi
			(( i++ ))
		fi
	done
	((num_unman_ids=i-1))
fi

# pull guid default MAC gateway & DnsSuffix for each entry

	i=0
	while [ $i -lt $num_unman_ids ]
	do
		(( i++ ))
		unman_guid[$i]=`echo ${temp_string_mac[$i]##*ProfileGuid (REG_SZ) = }`
		unman_guid[$i]=`echo ${unman_guid[$i]:0:38}`		# cut off as far as next (REG_???)
		unman_gate_mac[$i]=`echo ${temp_string_mac[$i]##*DefaultGatewayMac (REG_BINARY) = }`
		unman_gate_mac[$i]=`echo ${unman_gate_mac[$i]:0:17}`	# cut off as far as next (REG_???)
		unman_dnssuf[$i]=`echo "${temp_string_mac[$i]##*DnsSuffix (REG_SZ) = }"`
		unman_dnssuf[$i]=`echo ${unman_dnssuf[$i]%%$linefeed*}`
	done

# check through profile guids if match found in Unmanaged then assign default gateway & dns suffix 

	i=0
	while [ $i -lt $num_profiles ]
	do
		(( i++ ))
		x=0
		while [ $x -lt $num_unman_ids ]
		do	
			(( x++ ))
			if [ ${unman_guid[$x]} = ${profile_guid[$i]} ]
			then
				profile_gate_mac[$i]=${unman_gate_mac[$x]}
				if [ -f "oui.txt" ]
				then
					# look up ieee db for hw manufacturer
					oui=`echo ${profile_gate_mac[$i]:0:2}${profile_gate_mac[$i]:3:2}${profile_gate_mac[$i]:6:2} | tr '[:lower:]' '[:upper:]'`
 					if [ ${oui:0:1} != "(" ]
					then
						machw=`cat oui.txt | grep $oui`  
						machw=${machw##*)}
						profile_gate_mac[$i]=${profile_gate_mac[$i]}" ("$machw")"
					fi
				fi
				profile_dnssuf[$i]=${unman_dnssuf[$x]}

			fi
		done
	done
fi # from if its vista>
}



##################################################################################################
# Get the "active" adapter information from 		        				 #
# HKLM\System\CurrentControlSet\Services\Tcpip\Paramters\Adapters 				 #
# Assigns:	$net_inst_guid[$i]								 #
# HKLM\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{guid}			 #
# Assigns:	$domain_name[$i]								 #
#		$dhcpip_address[$i]								 #
#		$ip_address[$i]									 #
#		$dhcp_enable[$i]								 #
#		$dhcp_server[$i]								 #
#		$dhcp_gwmac[$i]	+ machhw (ieee hardware)					 #
#		$dhcp_subnet[$i]								 #
#		$lease[$i]									 #
#		$lease_obtain_time[$i]								 #
#		$lease_term_time[$i]								 #
# HKLM\System\CCS\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\{guid}\Connection	 #
# Assigns:	$network_name[$i]								 #
#		$media_subtype[$i]								 #
#		$pnp_inst_id[$i]								 #
##################################################################################################

pull_out_network_interfaces_func () {

# get profile guids
temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Services\Tcpip\Parameters\Interfaces" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			# append entries to existing file ie >>
fi
if [ -z "$temp_string" ] 	 # if this is empty 
then
	echo="Check SYSTEM hive location"
else
	i=1
	temp1="blank"
	while [ "$temp1" != "$temp_string"  ]		# check to see if string changes if not then on last guid
	do
		temp1=$temp_string
		temp_string=`echo ${temp_string#*..\\\{}` # cut as far as next guid
		if [ "$temp1" != "$temp_string" ]
		then
			net_inst_guid[$i]=`echo "{"${temp_string:0:37}` # "{"guid}
			(( i++ ))
		fi
	done
	((num_net_inst=i-1))
	
# get each network instance and populate arrays for the identified guids from 			    
	
	i=0
	while [ $i -lt $num_net_inst ]
	do
		(( i++ ))
		temp_string[$i]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Services\Tcpip\Parameters\Interfaces"$bslash${net_inst_guid[$i]} -v` 
		temp_string_net[$i]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}"$bslash${net_inst_guid[$i]}"\Connection" -v 2>/dev/null` # don't want errs if key doesn't exist
	
		if [ "$logging" != "off" ]						
		then
			echo "${temp_string[$i]}${temp_string_net[$i]}" >> $expert_log_location	# append entries 
		fi
	done

# pull out name, ip adds, lease info etc from each network instance
 
	i=0
	while [ $i -lt $num_net_inst ]
	do
	  (( i++ ))
	  domain_name[$i]=`echo "${temp_string[$i]##*Domain (REG_SZ) = }"`
	  if [ "${domain_name[$i]}" != "${temp_string[$i]}" ]
	  then
		domain_name[$i]=`echo ${domain_name[$i]%%$linefeed*}`
		echo ${temp_string[$i]} | grep -q "DhcpIPAddress"
		if [ $? = "0" ]						# hives vary
		then
			dhcpip_address[$i]=`echo "${temp_string[$i]##*DhcpIPAddress (REG_SZ) = }"`
			dhcpip_address[$i]=`echo ${dhcpip_address[$i]%%$linefeed*}`
		else
			dhcpip_address[$i]="Not recorded"
		fi 
		ip_address_temp[$i]=`echo "${temp_string[$i]##*DhcpIPAddress (REG_SZ) = }"` # get rid of DHCP entry if first
		ip_address[$i]=`echo "${temp_string[$i]##*IPAddress (REG_SZ) = }"`
		if [ "${ip_address_temp[$i]}" != "${ip_address[$i]}" ] # if $ changes ie you have found an IP entry
		then
			ip_address[$i]=`echo ${ip_address[$i]%%$linefeed*}`	
		else
			ip_address[$i]="Not recorded"
		fi
		dhcp_enable[$i]=`echo "${temp_string[$i]##*EnableDHCP (REG_DWORD) = }"`
		dhcp_enable[$i]=`echo ${dhcp_enable[$i]:9:1}`
		if [ "${dhcp_enable[$i]}" = "1" ]
		then
			dhcp_enable[$i]="yes"
		else
			dhcp_enable[$i]="no"
		fi
		echo ${temp_string[$i]} | grep -q "DhcpServer"
		if [ $? = "0" ]						# hives vary
		then	
			dhcp_server[$i]=`echo "${temp_string[$i]##*DhcpServer (REG_SZ) = }"`
			dhcp_server[$i]=`echo ${dhcp_server[$i]%%$linefeed*}`
		else
			dhcp_server[$i]="Not recorded"
		fi
		echo ${temp_string[$i]} | grep -q "DhcpGatewayHardware"
		if [ $? = "0" ]						# hives vary
		then	
			dhcp_gwmac[$i]=`echo "${temp_string[$i]##*DhcpGatewayHardware (REG_BINARY) = }"`
			dhcp_gwmac[$i]=`echo ${dhcp_gwmac[$i]%%$linefeed*} | tr -d " "`
			dhcp_gwmac[$i]=${dhcp_gwmac[$i]:16:2}" "${dhcp_gwmac[$i]:18:2}" "${dhcp_gwmac[$i]:20:2}" "${dhcp_gwmac[$i]:22:2}" "${dhcp_gwmac[$i]:24:2}" "${dhcp_gwmac[$i]:26:2}
			if [ -f "oui.txt" ]
			then
				oui=`echo ${dhcp_gwmac[$i]:0:2}${dhcp_gwmac[$i]:3:2}${dhcp_gwmac[$i]:6:2} | tr '[:lower:]' '[:upper:]'` # look up ieee db for hw manufacturer
				machw=`cat oui.txt | grep $oui`  
				machw=${machw##*)}
				dhcp_gwmac[$i]=${dhcp_gwmac[$i]}" ("$machw" )"
			fi
		else
			dhcp_gwmac[$i]="Not recorded"
		fi	
	
		echo ${temp_string[$i]} | grep -q "DhcpSubnetMask"
		if [ $? = "0" ]						# hives vary
		then
			dhcp_subnet[$i]=`echo "${temp_string[$i]##*DhcpSubnetMask (REG_SZ) = }"`
			dhcp_subnet[$i]=`echo ${dhcp_subnet[$i]%%$linefeed*}`	
		else
			dhcp_subnet[$i]=""
		fi
		echo ${temp_string[$i]} | grep -q "Lease ("
		if [ $? = "0" ]						# hives vary
		then
 			lease[$i]=`echo "${temp_string[$i]##*Lease (REG_DWORD) = }"`
			lease[$i]=`echo ${lease[$i]%%$linefeed*}`
		else
			lease[$i]="Not recorded"
		fi
		echo ${temp_string[$i]} | grep -q "LeaseObtainedTime"
		if [ $? = "0" ]						# hives vary
		then	
			lease_obtain_time[$i]=`echo ${temp_string[$i]##*LeaseObtainedTime (REG_DWORD) = }`
			lease_obtain_time[$i]=`echo ${lease_obtain_time[$i]%%(REG*}`
			lease_obtain_time[$i]=`echo ${lease_obtain_time[$i]##*\(}`
			lease_obtain_time[$i]=`echo ${lease_obtain_time[$i]%%\)*}` 
			if [ ${lease_obtain_time[$i]} -gt "0" ]		# 0 = 01/01/1970
			then
				lease_obtain_time[$i]=`date -d @${lease_obtain_time[$i]}`
			else
				lease_obtain_time[$i]="Not available"
			fi
		else
			lease_obtain_time[$i]="Not recorded"
		fi
		echo ${temp_string[$i]} | grep -q "LeaseTerminatesTime"
		if [ $? = "0" ]						# hives vary
		then	
			lease_term_time[$i]=`echo ${temp_string[$i]##*LeaseTerminatesTime (REG_DWORD) = }`
			lease_term_time[$i]=`echo ${lease_term_time[$i]%%(REG*}`
			lease_term_time[$i]=`echo ${lease_term_time[$i]##*\(}`
			lease_term_time[$i]=`echo ${lease_term_time[$i]%%\)*}` 
			if [ ${lease_term_time[$i]} -gt "0" ]		# 0 = 01/01/1970
			then 
				lease_term_time[$i]=`date -d @${lease_term_time[$i]}`
			else
				lease_term_time[$i]="Not available"
			fi
		else
			lease_term_time[$i]="Not Recorded"
		fi
	
				
# pull out name, Pnp instance id & Media Subtype from each network instance 

		network_name[$i]=`echo "${temp_string_net[$i]##*Name (REG_SZ) = }"`
		network_name[$i]=`echo ${network_name[$i]%%$linefeed*}`	
		echo ${temp_string_net[$i]} | grep -q "MediaSubType" 
		if [ $? = "0" ]						# hives vary
		then
			media_subtype[$i]=`echo "${temp_string_net[$i]##*MediaSubType (REG_DWORD) = }"`
			media_subtype[$i]=`echo ${media_subtype[$i]%%$linefeed*}`
		else
			media_subtype[$i]="Not Available"
		fi
		pnp_inst_id[$i]=`echo "${temp_string_net[$i]##*PnpInstanceID (REG_SZ) = }"`
		pnp_inst_id[$i]=`echo ${pnp_inst_id[$i]%%$linefeed*}`	
		
	  fi
	done
fi
}

##################################################################
# get Network Card description      				 #
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\NetworkCards #
# Assigns:	$inst_nic_desc[$i]				 #	
##################################################################

get_netcard_func () {

temp_string_net=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkCards" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string_net" >> $expert_log_location		# append entries to existing file ie >>
fi
if [ -z "$temp_string_net" ] 	 				# if this is empty 
then
	echo="Check SOFTWARE hive location"
else
	i=1
	temp1="blank"
	while [ "$temp1" != "$temp_string_net"  ]		# check to see if string doesn't changed then on last num
	do
		temp1=$temp_string_net
		temp_string_net=`echo ${temp_string_net#*..?}` 	# cut as far as number
		if [ "$temp1" != "$temp_string_net" ]
		then
			nic_num[$i]=`echo ${temp_string_net%% *}` # take num as far as next space
			temp_string_net[$i]=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\NetworkCards"$bslash${nic_num[$i]} -v` 		# get the guid & macadd
			if [ "$logging" != "off" ]						
			then
				echo "${temp_string_net[$i]}" >> $expert_log_location # append entries
			fi
			(( i++ ))
		fi
	done
((num_nics=i-1))
fi

# pull guid & hardware description from each entry

i=0
while [ $i -lt $num_nics ]
do
	(( i++ ))
	nic_guid[$i]=`echo ${temp_string_net[$i]##*ServiceName (REG_SZ) = }`
	nic_guid[$i]=`echo ${nic_guid[$i]:0:38}`			# cut off guid length
			
	nic_desc[$i]=`echo "${temp_string_net[$i]##*Description (REG_SZ) = }"`
	nic_desc[$i]=`echo ${nic_desc[$i]%%$linefeed*}`			
done

# check through profile guids if match found in nics then assign h/w description to main array 


i=0
while [ $i -lt $num_net_inst ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_nics ]
	do	
		(( x++ ))
		if [ ${nic_guid[$x]} = ${net_inst_guid[$i]} ]
		then
			inst_nic_desc[$i]=${nic_desc[$x]}
		fi
	done
done

}

##########################################################################
# Get XP WAPs and MAC adds by NIC 		 			 #
# HKLM\software\Microsoft\WZCSVC\Parameters\Interfaces\{guids of nics}   #
# Assigns : 	$int_guid[$z]						 #
#		$int_wap_mac[$z$x]  (can be multiple WAPs for each NIC)	 #
#		$mac_hw	(ieee MAC hardware type, appended to int_wap_mac)#
#		$wap_encrypt_type[$z$x]					 #
#		$wap_authentication[$z$x]				 #
#		$wap_name[$z$x]						 #
#		$wap_last_access[$z$x]					 #
#		$wap[$z] (concatenation of above)			 #
# Scroll through net_inst_guids match with int_guids add any $wap[$z]s to#
# 		$nic_wap[$z]						 # 
##########################################################################

get_xpwaps_func () {

temp_string=`perl $regdump_location $software_hive_location "Microsoft\WZCSVC\Parameters\Interfaces" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 					# if this is empty 
then
	echo="Check software hive location"
else
	z=0
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
		then
			(( z++ ))
			int_guid[$z]=${eachline##*..?}
			int_guid_data[$z]=`perl $regdump_location $software_hive_location "Microsoft\WZCSVC\Parameters\Interfaces$bslash${int_guid[$z]}" -v`
		  	if [ "$logging" != "off" ]						
		  	then
				echo "${int_guid_data[$z]}" >> $expert_log_location
		  	fi
			morestatics="maybe"
			statnum="0"
			while [ $morestatics = "maybe" ]
			do
				statnum=`echo $statnum | tr '[:upper:]' '[:lower:]'` # statnum needs to be in lower case here
				case ${#statnum} in
				1) static="000"$statnum ;; 
				2) static="00"$statnum ;;
				3) static="0"$statnum ;; 
				*) static=$statnum ;;
				esac 
				statnum=`echo $statnum | tr '[:lower:]' '[:upper:]'` # convert back to upper case
				echo "${int_guid_data[$z]}" | grep -q "Static#"$static
				if [ $? = "0" ]						
				then
					(( x=statnum+1 ))	# x used to count number of waps for each nic
					ts=`echo "${int_guid_data[$z]#*Static\#$static (REG_BINARY) = }"`
					ts=`echo ${ts%%$linefeed*} | tr -d " "`
					int_wap_mac[$z$x]=${ts:16:2}" "${ts:18:2}" "${ts:20:2}" "${ts:22:2}" "${ts:24:2}" "${ts:26:2}
					if [ -f "oui.txt" ]
					then
						# look up ieee db for hw manufacturer
						oui=`echo ${int_wap_mac[$z$x]:0:2}${int_wap_mac[$z$x]:3:2}${int_wap_mac[$z$x]:6:2} | tr '[:lower:]' '[:upper:]'` 
						machw=`cat oui.txt | grep $oui`  
						machw=${machw##*)??}	# ?? takes out the two tabs
						int_wap_mac[$z$x]=${int_wap_mac[$z$x]}" ("$machw")"
					fi
					len_wap_name[$z$x]=`echo ${ts:32:2} | tr '[:lower:]' '[:upper:]'`
					len_wap_name[$z$x]=`echo "ibase=16;obase=A;${len_wap_name[$z$x]}" | bc`
					wap_encrypt_type[$z$x]=${ts:104:2}
					case ${wap_encrypt_type[$z$x]} in
					00) wap_encrypt_type[$z$x]="WEP" ;; 
					01) wap_encrypt_type[$z$x]="Disabled" ;;
					04) wap_encrypt_type[$z$x]="TKIP" ;;
					06) wap_encrypt_type[$z$x]="AES" ;;
					*) wap_encrypt_type[$z$x]=${wap_encrypt_type[$z$x]} ;;
					esac
					wap_authentication[$z$x]=${ts:296:2}
					case ${wap_authentication[$z$x]} in
					00) wap_authentication[$z$x]="Open" ;; 
					01) wap_authentication[$z$x]="Shared" ;;
					03) wap_authentication[$z$x]="WPA" ;;
					04) wap_authentication[$z$x]="WPA-PSK" ;;
					*) wap_authentication[$z$x]=${wap_authentication[$z$x]} ;;
					esac
					
					y=0
					while [ $y -lt ${len_wap_name[$z$x]} ]
					do
						wap_name[$z$x]=${wap_name[$z$x]}${ts:(40+($y*2)):2} # 40 = 0x14 *2 start of name
						(( y++ ))
					done
					wap_name[$z$x]=`echo ${wap_name[$z$x]} | xxd -r -p`
					if [ ${#ts} -gt "1390" ]	# date at offset 0x2b8 (696*2) not always there 
					then
						wap_last_access[$z$x]=${ts:1406:2}${ts:1404:2}${ts:1402:2}${ts:1400:2}${ts:1398:2}${ts:1396:2}${ts:1394:2}${ts:1392:2}
						wap_last_access[$z$x]=`echo $((0x${wap_last_access[$z$x]}/10000000-11644473600))`  #convert windowstime to unix time
						wap_last_access[$z$x]=`date -d @${wap_last_access[$z$x]} 2>/dev/null`			      #convert unixtime
					fi
					wap[$z]=${wap[$z]}"$lfcr""     "${wap_name[$z$x]}"$lfcr""       WAP MAC        - "${int_wap_mac[$z$x]}"$lfcr""       Encryption     - "${wap_encrypt_type[$z$x]}"$lfcr""       Authentication - "${wap_authentication[$z$x]}"$lfcr""       Last access    - "${wap_last_access[$z$x]}"$lfcr"
					statnum=`echo "obase=16;ibase=16;($statnum+1)" | bc` # equiv of x=x+1 in hex
				else
					morestatics="no"
				fi
				num_statics[$z]=`echo "obase=A;ibase=16;$statnum" | bc` 
			done 
		fi
	done
	IFS=$p
	((num_int_guids=z))
fi
# loop thru all the nic_guids and match with the int_guids if a match associate the wap
i=0
while [ $i -lt $num_net_inst ]
do
	(( i++ ))
	nic_wap[$i]=" "			
	z=0
	while [ $z -lt $num_int_guids ]
	do
		(( z++ ))
		if [ ${net_inst_guid[$i]} = ${int_guid[$z]} ]
		then
			nic_wap[$i]="${wap[$z]}"
			z=$num_int_guids
		fi
	done
done
}

#################################################################
# get lanman outgoing network shares system wide		#
# HKLM\System\CurrentControlSet\Services\LanmanServer\Shares 	#
# Assigns:	$shares						#
#################################################################

get_shares_func () {

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Services\LanmanServer\Shares" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location		# append entries to existing file ie >>
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
then
	echo="Check system hive location"
else
	shares=""
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		echo $eachline | grep -q "(REG_MULTI_SZ)"
		if [ $? = "0" ]
		then
			sharename=`echo ${eachline%%(*}`
			path=`echo ${eachline##*Path=}`
			path=`echo ${path%%[*}`
			shares=$shares"  name : "$sharename"$lfcr""  path : "$path"$lfcr$lfcr"
		fi
	done
	IFS=$p
fi
}

##############################################
# function to convert network profile        #
# times to readable format                   #
##############################################

convert_profile_func () {

year=$(echo "ibase=16;${temp:3:2}${temp:0:2}" | bc)	# strip out little endian year
month=$(echo "ibase=16;${temp:9:2}${temp:6:2}" | bc)	# strip out little endian month
month=`date -d "01-$month-01" +%B`
dow=$(echo "ibase=16;${temp:15:2}${temp:12:2}" | bc)	# get day of week
dowarray=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
dow=${dowarray[$dow]}			
dom=$(echo "ibase=16;${temp:21:2}${temp:18:2}" | bc)	# get day of month
hour=$(echo "ibase=16;${temp:27:2}${temp:24:2}" | bc)	# get time
if [ `echo ${#hour}` -lt 2 ]
then
	hour="0"$hour
fi
min=$(echo "ibase=16;${temp:33:2}${temp:30:2}" | bc)
if [ `echo ${#min}` -lt 2 ]
then
	min="0"$min
fi
sec=$(echo "ibase=16;${temp:39:2}${temp:36:2}" | bc)
if [ `echo ${#sec}` -lt 2 ]
then
	sec="0"$sec
fi
fsec=$(echo "ibase=16;${temp:45:2}${temp:42:2}" | bc)
if [ `echo ${#fsec}` -lt 2 ]
then
	fsec="0"$fsec
fi
temp=$dow" "$dom" "$month" "$year" "$hour":"$min":"$sec":"$fsec
		
}

#############################################
#         Output info to screen             #
#############################################

output_to_screen_func () {
if [ "$logging" = "off" ]						
then
	log_location="/dev/null"
fi

if [ "$num_profiles" > "0" ]
then
	i=0
	echo "NETWORK PROFILES RECORDED ON THIS SYSTEM" | tee $log_location
	echo | tee -a $log_location
	while [ $i -lt $num_profiles ]
	do
		(( i++ ))
		echo ${profile_name[$i]} | tee -a $log_location
		echo "   guid                : "${profile_guid[$i]} | tee -a $log_location
		echo "   Date created        : "${profile_date_created[$i]} | tee -a $log_location
		echo "   Last connected      : "${profile_last_con[$i]} | tee -a $log_location
		echo "   Default Gateway MAC : "${profile_gate_mac[$i]} | tee -a $log_location
		echo "   DNS suffix          : "${profile_dnssuf[$i]} | tee -a $log_location
		if [ "$win7" = "yes" ]	# win 7 only #
		then
			echo "   Profile location    : "${profile_location[$i]} | tee -a $log_location
		fi
		echo | tee -a $log_location
	done
fi

i=0
echo "ACTIVE NETWORK INSTANCES RECORDED ON THIS SYSTEM" | tee -a $log_location
echo | tee -a $log_location
while [ $i -lt $num_net_inst ]
do	
	(( i++ ))
	if [ "${domain_name[$i]}" != "${temp_string[$i]}" ]	# if there is anything of interest often lots of "empties"
	then
		echo "Network instance guid "${net_inst_guid[$i]} | tee -a $log_location
		echo | tee -a $log_location	
		echo "  Hardware           : "${inst_nic_desc[$i]} | tee -a $log_location 
		echo "  Domain name        : "${domain_name[$i]} | tee -a $log_location
		echo "  Dhcp IP Address    : "${dhcpip_address[$i]}" ("${dhcp_subnet[$i]}")" | tee -a $log_location
		echo "  Dhcp Server        : "${dhcp_server[$i]} | tee -a $log_location
		echo "  Dhcp Enabled       : "${dhcp_enable[$i]} | tee -a $log_location
		echo "  Dhcp gateway MAC   : "${dhcp_gwmac[$i]} | tee -a $log_location
		echo "  Lease period (secs): "${lease[$i]} | tee -a $log_location
		echo "  Lease obtained     : "${lease_obtain_time[$i]} | tee -a $log_location
		echo "  Lease Terminates   : "${lease_term_time[$i]} | tee -a $log_location
		echo "  Static IP Address  : "${ip_address[$i]} | tee -a $log_location
		echo "  Network Connection : "${network_name[$i]} | tee -a $log_location
		echo "  Media Subtype      : "${media_subtype[$i]} | tee -a $log_location
		echo "  Pnp Inst ID : "${pnp_inst_id[$i]} | tee -a $log_location
		if [ "${nic_wap[$i]}" != " " ] && [ "$wpd" != "yes" ]
		then
			echo "  Wireless access points accessed by this NIC :" | tee -a $log_location
			echo "${nic_wap[$i]}" | tee -a $log_location
		fi
		echo | tee -a $log_location
				
	fi
done
if [ -n "$shares" ]
then
	echo "OUTGOING SHARES :" | tee -a $log_location
	echo | tee -a $log_location
	echo "$shares" | tee -a $log_location
	echo | tee -a $log_location
fi	
}

#############################################
#	Main process			    #
#############################################

# check if the args are valid
if [ "$1" = "-h" ]
then
	cmd_line_help_func
	exit
fi

while [ $# -gt 1 ]
	do
	case $1 in
	-S) system_hive_location=$2 ; shift 2 ;;
	-A) setupapi_location=$2 ; shift 2 ;;
	-N) ntuser_location=$2 ; shift 2;;
	-W) software_hive_location=$2 ; shift 2;;
	-C) security_hive_location=$2 ; shift 2;;
	-D) default_location=$2	; shift 2;;
	-M) sam_location=$2 ; shift 2;;
	-E) logging=$2 ; shift 2;;
	-L) logpath=$2 ; shift 2;;
	*) shift 1;;
	esac 
done

if [ -z $system_hive_location ]
then
	system_hive_location=$default_location"/system"
	if [ ! -f "$system_hive_location" ]				# Vista + generally system is SYSTEM ?
	then
		system_hive_location=$default_location"/SYSTEM"
	fi
fi
if [ -z $ntuser_location ]
then
	ntuser_location=$default_location"/NTUSER.DAT"
fi
if [ -z $software_hive_location ]
then
	software_hive_location=$default_location"/software"
	if [ ! -f "$software_hive_location" ]				# Vista + generally software is SOFTWARE ?
	then
		software_hive_location=$default_location"/SOFTWARE"
	fi
fi
if [ -z $security_hive_location ]
then
	security_hive_location=$default_location"/SECURITY"
fi

if [ -z $sam_location ]
then
	sam_location=$default_location"/SAM"
fi
if [ ! -z $logpath ]
then
	if [ ! -d $logpath ]
	then
		mkdir $logpath
	fi
	expert_log_location=$logpath"/"$expert_log_location
	log_location=$logpath"/"$log_location
fi

# check that the hives you want exist

if [ ! -f "$system_hive_location" ]
	then
		clear
		echo "You must enter a valid SYSTEM hive"
		cmd_line_help_func
		exit
fi

if [ ! -f "$software_hive_location" ]
	then
		clear
		echo "You must enter a valid SOFTWARE hive"
		cmd_line_help_func
		exit
fi

# if args are valid run functions
current_control_set_func
pull_out_winver_func
pull_out_network_ap_func
pull_out_network_interfaces_func
get_macadd_func
get_netcard_func
if [ "$wpd" != "yes" ]	# xp only #
then
	get_xpwaps_func
fi
get_shares_func
output_to_screen_func
exit


