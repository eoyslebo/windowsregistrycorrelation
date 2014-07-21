#!/bin/bash 
###############################################
# Utility to present System information       #
# information in a clear and connected manner #
# Jacky Fox 2012                              #
###############################################

#############################################
# variable settings			    #
#############################################

regdump_location="/usr/local/bin/regdump.pl"
expert_log_location="system_expert.log"	# location of unfiltered output for evidential purposes
log_location="system.log"	 	# location of sorted and related system log
i=0
bslash='\'
crlf="\r\n"
lfcr="\n\r"
lfcr=`echo -e $lfcr`
linefeed=$'\n'

##########################################
#   command line help function           #
##########################################

# comment out lines for unrequired hives/files

cmd_line_help_func() {

echo "usage : "$0" -S ../hives/SYSTEM "
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

#########################################
# Extract current control set number  	#
# HKLM\SYSTEM\Select			#
# Assigns: 	$ccs			#
#########################################

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

###################################################################
# Get the computer name from 		 			  #
# HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName #
# Assigns: 	$comp_name					  #
###################################################################

get_compname_func () {

	temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\ComputerName\ComputerName" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			# append entries to existing file ie >>
	fi
	if [ -z "$temp_string" ] 	 					 
	then
		echo Unable to extract computer name check SYSTEM hive location
	else
		comp_name=`echo "${temp_string##*ComputerName (REG_SZ) = }"` 	# cut off leading info
		comp_name=`echo ${comp_name%%$linefeed*}`			# truncate at linefeed
	fi
}

#################################################################
# Pull out the windows version, install date, registered owner  #
# & organization, service pack level, system root, and product	#
# name from:HKLM\Software\Microsoft\Windows NT\CurrentVersion	#
# Assigns:	$reg_org					#
#		$reg_own					#
#		$win_ver					#
#		$cur_ver					#
#		$sys_root					#
#		$prod_id					#
#		$service_pack_ver				#
#		$inst_date					#
#################################################################

get_winnt_cv_func () {
	temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location		# append entries to file >>
	fi
	if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		reg_org="Not available (check SOFTWARE hive location)"
	else
		reg_org=`echo "${temp_string##*RegisteredOrganization (REG_SZ) = }"` 	# cut out leading info
		reg_org=`echo ${reg_org%%$linefeed*}`					# truncate at linefeed
		reg_own=`echo "${temp_string##*RegisteredOwner (REG_SZ) = }"` 
		reg_own=`echo ${reg_own%%$linefeed*}`
		win_ver=`echo "${temp_string##*ProductName (REG_SZ) = }"` 	
		win_ver=`echo ${win_ver%%$linefeed*}`
		echo $win_ver | grep -q "Windows 7\|Windows Vista" 	# check if windows is >= Vista
		if [ $? = "0" ]					
		then						
			wpd="yes"
		fi		
		cur_ver=`echo "${temp_string##*CurrentVersion (REG_SZ) = }"`
		cur_ver=`echo ${cur_ver%%$linefeed*}`
		sys_root=`echo "${temp_string##*SystemRoot (REG_SZ) = }"`
		sys_root=`echo ${sys_root%%$linefeed*}`
		prod_id=`echo "${temp_string##*ProductId (REG_SZ) = }"`
		prod_id=`echo ${prod_id%%$linefeed*}`
		echo $temp_string | grep -q "CSDVersion"
		if [ $? = "0" ]					
		then		
			service_pack_ver=`echo "${temp_string##*CSDVersion (REG_SZ) = }"`
			service_pack_ver=`echo ${service_pack_ver%%$linefeed*}`
		fi
		inst_date=`echo "${temp_string##*InstallDate (REG_DWORD) = }"`
		inst_date=`echo ${inst_date%%$linefeed*}`
		inst_date=`echo ${inst_date%% (*}`
 		inst_date=`echo $(($inst_date))`
		inst_date=`date -d @$inst_date`
	fi
}

#################################################
# Get the last shutdown time and the system     #
# directory from 		                #
# HKLM\System\CurrentControlSet\Control\Windows #
# Assigns:	$shutdown_time			#
#		$sys_dir			#
#################################################

get_control_func () {
	temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\Windows" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			# append entries to file >>
	fi 
	if [ -z "$temp_string" ] 	 					# if this is empty 
	then
		shutdown_time="Not available (check SYSTEM hive location)"
	else
		echo $temp_string | grep -q "ShutdownTime"
		if [ $? = "0" ]							# if there is a ShutdownTime		
		then						
		 shutdown_time=`echo ${temp_string##*ShutdownTime (REG_BINARY) = }` 	#cut out leading info
		 tem=`echo $shutdown_time | tr -d " "`            # get rid of spaces - line below little endian convert
		 shutdown_time=`echo ${tem:14:2}${tem:12:2}${tem:10:2}${tem:8:2}${tem:6:2}${tem:4:2}${tem:2:2}${tem:0:2}`
 		 shutdown_time=`echo $((0x$shutdown_time/10000000-11644473600))`    	#convert windowstime to unix time
		 shutdown_time=`date -d @$shutdown_time`				#convert unixtime 
		else
		 shutdown_time="Not recorded in the registry"
		fi
		sys_dir=`echo "${temp_string##*SystemDirectory (REG_SZ) = }"`		
		sys_dir=`echo "${sys_dir##*SystemDirectory (REG_EXPAND_SZ) = }"` 	# both types have been seen
		sys_dir=`echo ${sys_dir%%$linefeed*}` 		   			# cut trailing	
	fi
}

############################################################
# Get the last user logged in to the system      	   #
# HKLM\System\Microsoft\Windows NT\CurrentVersion\Winlogon #
# Assigns:	$last_logged_user			   #
############################################################

get_last_logged_in_func () {
	temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\Winlogon" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	echo $temp_string | grep -q "DefaultUserName"
	if [ $? = "0" ]					
	then
		last_logged_user=`echo "${temp_string##*DefaultUserName (REG_SZ) = }"`
		last_logged_user=`echo ${last_logged_user%%$linefeed*}`
	fi

}

#########################################################
# Get system wide autoruns from the system	   	#
# HKLM\System\Microsoft\Windows\CurrentVersion\Run	#
# Assigns:	$syswide_autorun			#
#########################################################

get_systemwide_autorun_func () {
	temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows\CurrentVersion\Run" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`
	do
		echo $eachline | grep -q " ="
		if [ $? = "0" ]
		then
			syswide_autorun=$syswide_autorun$IFS${eachline##* =}
		fi
	done
	IFS=$p
}
#################################################################
# Get installed apps names and dates from the software hive	#
# HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall	#
# Assigns:	$installed_apps_uninst				#
#################################################################

get_uninstall_apps_func () {
installed_apps_uninst=""
i=0
temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows\CurrentVersion\Uninstall" -v `
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
p=$IFS
IFS=$'\n'
for eachline in `echo "$temp_string"`				
do
	if [ "${eachline:0:2}" = ".." ]				# if the line holds an extention subkey
	then
		uninst_ext=${eachline##*..?}
		temp_string2=`perl $regdump_location $software_hive_location "Microsoft\Windows\CurrentVersion\Uninstall$bslash$uninst_ext" -v 2>/dev/null` 				# nb regdump does not like kanji chars in key names
		if [ "$logging" != "off" ]		 	
		then
			echo "$temp_string2" >> $expert_log_location
	  	fi
		uninst_date=${temp_string2%%]*}
		uninst_date=`echo ${uninst_date##*[} | tr "T" " " | tr "Z" " "`"(UTC)"
		echo $temp_string2 | grep -q "DisplayName"
		if [ $? = "0" ]
		then
			uninst_name=`echo "${temp_string2##*DisplayName (REG_SZ) = }"`
			uninst_name=`echo ${uninst_name%%$linefeed*}`
		else
			uninst_name=$uninst_ext
		fi
		installed_apps_uninst=$installed_apps_uninst" "$uninst_name" --- "$uninst_date"$lfcr"
	fi
done
IFS=$p
}


#####################################################
# Pull out a list of  drive letters ever used from  #
# HKLM\System\MountedDevices		  	    #
# Assigns:	$drive_letters			    #
#####################################################

get_driveletters_func () {
	temp_string=`perl $regdump_location $system_hive_location "MountedDevices" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location	
	fi 
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`			# strip out each driver letter ever used
	do
		echo $eachline | grep -q "DosDevices"
		if [ $? = "0" ]
		then
			drive_letters=$drive_letters${eachline:12:2}" "
		fi
	done
	IFS=$p
}

##################################################################
# Find out if time is network time protocol synchronized or not  #
# HKLM\System\CurrentControlSet\Services\W32Time\Parameters      #
# Assigns:	$ntp_type				         #
##################################################################

get_ntp_func () {
	temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Services\W32Time\Parameters" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ] 	 # if this is empty 
	then
		ntp_type="Not available (check SYSTEM hive location)"
	else
		ntp_type=`echo ${temp_string##*Type (REG_SZ) = }` #cut out leading info
		ntp_type=`echo ${ntp_type:0:3}` 
		if [ $ntp_type = "NTP" ]
		then
			ntp_type="synchronised"
		else
			ntp_type="not Synchronised" 
		fi	
	fi

}

#############################################################
# Get the timezone info from	                	    #
# HKLM\System\CurrentControlSet\Control\TimeZoneInformation #
# Assigns:	$tz_last_update				    #
#		$tz_daylight_name			    #
#		$tz_daylight_start			    #
#		$tz_standard_name			    #
#		$tz_standard_start			    #
#		$tz_key_name				    #
#		$tz_at_bias				    #
#		$tz_dl_bias				    #
#		$tz_st_bias				    #
#		$tz_bias				    #
#############################################################

get_timezone_func () {
	temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\TimeZoneInformation" -v` 
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ] 	 
	then
		tz_last_update="Not available (check SYSTEM hive location)"
	else
		tz_last_update=`echo "${temp_string##*TimeZoneInformation [}"` 		#cut out leading info
		tz_last_update=`echo ${tz_last_update%%]*} | tr "T" " " | tr "Z" " "`"(UTC)"
		tz_daylight_name=`echo "${temp_string##*DaylightName (REG_SZ) = }"` 
		tz_daylight_name=`echo ${tz_daylight_name%%$linefeed*}`
 		tz_daylight_start=`echo ${temp_string##*DaylightStart (REG_BINARY) = }` 
		temp=`echo ${tz_daylight_start:0:47} | tr '[:lower:]' '[:upper:]'`
		convert_start_func							#put daylight start into english
		tz_daylight_start=$dow" in the "$wom" week of "$month" at "$time
		tz_standard_name=`echo "${temp_string##*StandardName (REG_SZ) = }"` 
		tz_standard_name=`echo ${tz_standard_name%%$linefeed*}`
		tz_standard_start=`echo ${temp_string##*StandardStart (REG_BINARY) = }` 
		temp=`echo ${tz_standard_start:0:47} | tr '[:lower:]' '[:upper:]'`
		convert_start_func
		tz_standard_start=$dow" in the "$wom" week of "$month" at "$time	#put standard start into english

		if [ "$wpd" = "yes" ]						   	# if vista+
		then
			tz_key_name=`echo "${temp_string##*TimeZoneKeyName (REG_SZ) = }"` 
			tz_key_name=`echo ${tz_key_name%%]*}`
			tz_key_name1=`echo ${tz_key_name%%Time*}` # this key seems to pick up slack cutting off at the
			if [ "$tz_key_name1" !=  "$tz_key_name" ] # word Time often but not always makes it clearer to read
			then					  # the original entry is in the expert log
				tz_key_name=$tz_key_name1" Time"  # add the word " Time" back in
			fi
		fi						 

		tz_at_bias=`echo "${temp_string##*ActiveTimeBias (REG_DWORD) = }"` 
		tz_at_bias=`echo ${tz_at_bias%%$linefeed*} | tr '[:lower:]' '[:upper:]'`
		result=$(echo "obase=2;ibase=16;${tz_at_bias:2:8}" | bc)
		hex_to_mins_func
		tz_at_bias=$mins		
		
		tz_dl_bias=`echo "${temp_string##*DaylightBias (REG_DWORD) = }"` 
		tz_dl_bias=`echo ${tz_dl_bias%%$linefeed*} | tr '[:lower:]' '[:upper:]'`
		result=$(echo "obase=2;ibase=16;${tz_dl_bias:2:8}" | bc)
		hex_to_mins_func
		tz_dl_bias="Bias"${mins##*UTC}

		tz_st_bias=`echo "${temp_string##*StandardBias (REG_DWORD) = }"` 
		tz_st_bias=`echo ${tz_st_bias%%$linefeed*} | tr '[:lower:]' '[:upper:]'`
		result=$(echo "obase=2;ibase=16;${tz_st_bias:2:8}" | bc)
		hex_to_mins_func
		tz_st_bias="Bias"${mins##*UTC} 

		tz_bias=`echo "${temp_string#*$linefeedBias (REG_DWORD) = }"` 
		tz_bias=`echo ${tz_bias%%$linefeed*} | tr '[:lower:]' '[:upper:]'`
		result=$(echo "obase=2;ibase=16;${tz_bias:2:8}" | bc)
		hex_to_mins_func
		tz_bias=$mins			   			   
	fi
	
}

##############################################
# timezone start convert function for start  #
# of daylight saving and standard time       #
# set time into $temp before calling	     #
##############################################

convert_start_func () {
		month=$(echo "ibase=16;${temp:9:2}${temp:6:2}" | bc)	# strip out little endian month number to name
		month=`date -d "01-$month-01" +%B 2>/dev/null` 			
		wom=$(echo "ibase=16;${temp:15:2}${temp:12:2}" | bc)	# get week of month
		womarray=(not 1st 2nd 3rd 4th last)			
		wom=${womarray[$wom]}
		hour=$(echo "ibase=16;${temp:21:2}${temp:18:2}" | bc)	# get time
		if [ `echo ${#hour}` -lt 2 ]
			then
			hour="0"$hour
		fi
		min=$(echo "ibase=16;${temp:27:2}${temp:24:2}" | bc)
		if [ `echo ${#min}` -lt 2 ]
			then
			min="0"$min
		fi
		sec=$(echo "ibase=16;${temp:33:2}${temp:30:2}" | bc)
		if [ `echo ${#sec}` -lt 2 ]
			then
			sec="0"$sec
		fi
		fsec=$(echo "ibase=16;${temp:39:2}${temp:36:2}" | bc)
		if [ `echo ${#fsec}` -lt 2 ]
			then
			fsec="0"$fsec
		fi
		time=$hour":"$min":"$sec":"$fsec
		dow=$(echo "ibase=16;${temp:45:2}${temp:42:2}" | bc)	# get day of week
		dowarray=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
		dow=${dowarray[$dow]}
		
}

#########################################
#         Output info to screen         #
#########################################

output_to_screen_func () {
if [ "$logging" = "off" ]						
then
	log_location="/dev/null"
fi
	echo "Current Control Set       : "$ccs| tee $log_location	# nb first tee not -a for append
	echo "Registered Organization   : "$reg_org | tee -a $log_location
	echo "Registered Owner          : "$reg_own | tee -a $log_location
	echo "Computer Name             : "$comp_name | tee -a $log_location
	echo "Product serial number     : "$prod_id | tee -a $log_location
	echo "Product Name              : "$win_ver" "$service_pack_ver| tee -a $log_location
	echo "Current Version           : "$cur_ver | tee -a $log_location
	echo "System Root               : "$sys_root | tee -a $log_location
	echo "Installation Date         : "$inst_date | tee -a $log_location
	echo "Last logged Shutdown Time : "$shutdown_time | tee -a $log_location
	echo "Last user logged in       : "$last_logged_user | tee -a $log_location
	echo "System Directory          : "$sys_dir | tee -a $log_location
	echo "Drive letters             : "$drive_letters | tee -a $log_location
	echo "Daylight savings Timezone : "$tz_daylight_name" ("$tz_dl_bias")" | tee -a $log_location
	echo "Standard Timezone         : "$tz_standard_name" ("$tz_st_bias")" | tee -a $log_location
	if [ "$wpd" = "yes" ]						   # if vista+
		then	
		echo "Timezone name             : "$tz_key_name | tee -a $log_location
	fi
	echo "Timezone bias             : "$tz_bias | tee -a $log_location
	echo "Current time bias         : "$tz_at_bias | tee -a $log_location
	echo "Network time protocol is  : "$ntp_type | tee -a $log_location
	echo "Timezone last  updated    : "$tz_last_update | tee -a $log_location
	echo "Daylight saving starts on "$tz_daylight_start | tee -a $log_location
	echo "Standard time starts on "$tz_standard_start | tee -a $log_location
	echo | tee -a $log_location
	echo "SYSTEM WIDE AUTORUNS""$syswide_autorun" | tee -a $log_location
	echo | tee -a $log_location
	echo "INSTALLED APPLICATIONS (Uninstall)"| tee -a $log_location
	echo "$installed_apps_uninst"| tee -a $log_location
	

}

#############################################
# binary twos comp functions hex to mins    #
#############################################

hex_to_mins_func () {
res_len=${#result}
if [ $res_len -lt "32" ] # if length of binary number = 32 then leading bit is "1" else its a 0 and < 32 
then
	mins="UTC +"$(echo "ibase=2;$result" | bc)" Minutes"
else
	i=32
	flip="no"
	while [ $i -gt "1" ]
	do
		(( i-- ))
		res[$i]=${result:$i:1}
		if ([ "$flip" = "yes" ] && [ "${res[$i]}" = "1" ]) || ([ "$flip" = "no" ] && [ "${res[$i]}" = "0" ])
		then
			res[$i]="0"
		else
			res[$i]="1"
			flip="yes"
		fi
		
	done
	i=0; result=""
	while [ $i -lt "32" ]
	do
		(( i++ ))
		result=$result${res[$i]}
	done
	mins="UTC -"$(echo "ibase=2;${result:1:31}" | bc)" Minutes"
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

# if the hive locations are empty set them to the defaults #

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
get_winnt_cv_func
get_compname_func
get_control_func
get_timezone_func
get_ntp_func
get_last_logged_in_func
get_systemwide_autorun_func
get_driveletters_func
get_uninstall_apps_func
output_to_screen_func
exit


