#!/bin/bash 
###############################################
# Utility to present information about        #
# previously connected USB devices	      #
# in a clear and related manner. 	      #
# Jacky Fox 2012 			      #
# Dependancies regdump.pl                     #
###############################################

#############################################
# variable settings			    #
#############################################

regdump_location="/usr/local/bin/regdump.pl"
expert_log_location="usb_expert.log" # location of unfiltered output for evidential purposes
log_location="usb.log"	 # location of sorted and related usb log
device_counter=1
long_name_1="not blank"
vendorid_database="usb.ids"
months=( dummy Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ) # array for epoch conversion
i=0
x=0
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
echo "	-A (path and name of setupapi.log file)	-A ../hives/setupapi.dev.log"
echo "	-W (path and name of Software hive)	-W /samples/software"
echo "	-D (default location of hives)		-D myhives"
#echo "	-C (path and name of Security hive)	-C ../hives/SECURITY"
#echo "	-M (path and name of the SAM)		-M ../hives/SAM"
echo "	-E (switch off expert logs)		-E off"
echo "	-L (give explicit path for logs)	-L /logdir"
echo "	-K (explicit path to .lnk files 	-K myhives/linkfiles"
echo "	    default location myhives/lnk)" 
exit
}


#################################################
# Check current control set number  	  	#
# HKLM\SYSTEM\Select				#
# Assigns:	$ccs				#
#################################################

current_control_set_func () {
	
	temp_string=`perl $regdump_location $system_hive_location "Select" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" > $expert_log_location			# first entry so new file ie >
	fi
	if [ -z "$temp_string" ] 	 					# if this is empty 
	then
		ccs="Not available (check SYSTEM hive location)"
	else
 		ccs=`echo ${temp_string##*Current (REG_DWORD) = 0x}` 		#cut out leading info
		ccs=`echo ${ccs:5:3}` 			    	     		#cut off trailing info
	fi
}


###################################################################
# Get the computer name from 		 			  #
# HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName #
# Assigns:	$comp_name					  #
###################################################################

pull_out_compname_func () {

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
# Get the windows version from		      			#
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName #
# Assigns:	$win_ver					#
#		$wpd						#
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
	if [ $? = "0" ]						# portable devices may contain additional last drive
	then							# assignations and mountdev searches on s/n not parentid_
		wpd="yes"
	fi
}

##############################################
# Pull out the information from usbstor      #
# This requires getting a long device name   #
# and checking for the serial number(s)      #
# beneath it				     #
# HKLM\System\CurrentControlSet\Enum\USBSTOR #
# Assigns : 	$long_name_[$i]		     #
#		$serial_num_[$i]	     #
#		$friendly_name_[$i]	     #
#		$parentid_pf_[$i]	     #
#		$parentid_unicode_[$i]	     #
#		$sn_unicode_[$i]	     #
# unicode values are used to search mounted  #
# devices later for guids & drive assignments# 		
##############################################

pull_out_usbstor_func () {

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USBSTOR" -v 2>/dev/null`
if [ $? != "0" ]
then
	echo "There are no usb devices associated with this system"
	exit
fi
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
	if [ -z "$temp_string" ] 	 					# if this is empty 
	then
		echo="Check SYSTEM hive location"
	else
		i=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]				# check to see if string doesn't change 
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 			# cut as far as device long name
			if [ "$temp1" != "$temp_string" ]
			then
				long_name_[$i]=`echo ${temp_string%% *}` 	# take id as far as next space
				temp_string_sn=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USBSTOR"$bslash${long_name_[$i]} -v` 						# get the serial number(s)
				if [ "$logging" != "off" ]						
				then
					echo "$temp_string_sn" >> $expert_log_location			
				fi
				temp2=$temp_string_sn
				num_sns=`echo "$temp_string_sn" | grep -c '\.\.'` # how many serial numbers
				while [ "$num_sns" -gt "0" ]
				do
					temp_string_sn=$temp2
					temp_string_sn=`echo ${temp_string_sn#*..?}`
					temp2=`echo ${temp_string_sn# *}`
					serial_num_[$i]=`echo ${temp_string_sn%% *}`
					temp_string_sn=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USBSTOR"$bslash${long_name_[$i]}$bslash${serial_num_[$i]} -v` 			# get the serial number
					if [ "$logging" != "off" ]						
					then
						echo "$temp_string_sn" >> $expert_log_location			
					fi
					string_empty=`echo $temp_string_sn | grep -c "FriendlyName"`
					if [ $string_empty != 0 ]
					then 
						friendly_name_[$i]=`echo "${temp_string_sn##*FriendlyName (REG_SZ) = }"`
						friendly_name_[$i]=`echo ${friendly_name_[$i]%%$linefeed*}`
					else
						friendly_name_[$i]=" "
					fi
					if [ "$wpd" != "yes" ] 			# if it's xp
					then
						string_empty=`echo $temp_string_sn | grep -c "ParentIdPrefix"`
						if [ $string_empty != 0 ]
						then 
						   parentid_pf_[$i]=`echo "${temp_string_sn##*ParentIdPrefix (REG_SZ) = }"`
						   parentid_pf_[$i]=`echo ${parentid_pf_[$i]%%$linefeed*}`
						   #### conversion to unicode ####
						   parentid__utf16_[$i]=`echo ${parentid_pf_[$i]} |od -x`
						   x=5 				# x tracks position of 2 char hex code
						   while [ "$x" -gt "0" ]
						   do
							(( x=x+5 ))
							newchar=${parentid__utf16_[$i]:$x:2} 		# high char
							if [ "$newchar" != "0a" ]
							then
								parentid_unicode_[$i]=${parentid_unicode_[$i]}$newchar" 00 "
								newchar=${parentid__utf16_[$i]:($x-2):2} # low char
								if [ "$newchar" != "0a" ]
								then
								  parentid_unicode_[$i]=${parentid_unicode_[$i]}$newchar" 00 "
								else
								  x=0 					#stop the loop
								fi
							else
								x=0 					#stop the loop
							fi
						   done
						else
							parentid_pf_[$i]=" "
						fi
					fi
					####  convert serial # to unicode to get guids also if >=vista for parentid_s ####
						sn_utf16_[$i]=`echo ${serial_num_[$i]} |od -x`
						x=5 					# x tracks position of 2 char hex code
						while [ "$x" -gt "0" ]
						do
							(( x=x+5 ))
							newchar=${sn_utf16_[$i]:$x:2} 	# high char
							if [ "$newchar" = "00" ]
							then
								(( x=x+3 )) 		#skip the info at left side
							else
								if [ "$newchar" != "0a" ]
								then
								  sn_unicode_[$i]=${sn_unicode_[$i]}$newchar" 00 "
								  newchar=${sn_utf16_[$i]:($x-2):2} # low char
								  if [ "$newchar" = "00" ]
								  then
									(( x=x+3 )) 	#skip the info at left side
								  else
								  	if [ "$newchar" != "0a" ]
								  	then
									  sn_unicode_[$i]=${sn_unicode_[$i]}$newchar" 00 "
								  	else
								   	x=0 		#stop the loop
									fi
								  fi
								else						
								  x=0 			#stop the loop
								fi
							fi
						done
					if [ "$wpd" = "yes" ] 				# if it's vista or >
					then
						parentid_unicode_[$i]=${sn_unicode_[$i]} # mountd needs s/n not parentid_ 
					fi			
					(( num_sns-- ))
					(( i++ ))
					if [ "$num_sns" -gt "0" ] 			# more s/n? set longname & loop
					then
						long_name_[$i]=${long_name_[$i-1]}
					fi	
				done
			fi
		done
	((device_counter=i-1))
	fi
}
#################################################################
# Get product id and vendor id from     		    	#
# HKLM\System\CurrentControlSet\Enum\USB\Vid_9999&Pid_9999  	#
# HKLM\System\CurrentControlSet\Enum\ACPI			#
# Assigns :	$pid_num[$i]			        	#
#		$vid_num[$i]					#
#		$enumusb_last_insertion_[$i]			#
#		$vid_name[$i]					#
# possibly vendor name from id if usb.id can be found		#
#################################################################

pull_out_pidvid_func () {

#### first setup an array of all vid, pids, serial numbers and times #### 

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USB" -v` 
## get the epoch time of the Enum key to compare to other enum tree values to check if they are device specific ##
if [ "$wpd" = "yes" ]
then
	temp_enum=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\ACPI" -v`
	usbtime=`echo "${temp_enum%%\]*}"`
	usbtime=`echo "${usbtime##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
	if [ "${usbtime:5:1}" = "0" ]	# date command gets upset with 08 & 09 ?? 
	then
		mon=${usbtime:6:1}
	else
		mon=${usbtime:5:2}
	fi
	epoch_usb=`date +%s -d ${months[$mon]}" "${usbtime:8:2}", "${usbtime:0:4}" "${usbtime:11:8}`
fi
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SYSTEM hive location"
	else
		x=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]		# check to see if string doesn't changed then on last entry
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 	# cut as far as next vidpid
			if [ "$temp1" != "$temp_string" ]
			then
				pidvid[$x]=`echo ${temp_string%% *}` 	# take id as far as next space
				vid[$x]=${pidvid[$x]:4:4}
				pid[$x]=${pidvid[$x]:13:4}
				tempy=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USB"$bslash${pidvid[$x]} -v` 
				if [ "$logging" != "off" ]						
				then
					echo "$tempy" >> $expert_log_location	
				fi
				tempy1="blank"
				while [ "${tempy}" != "${tempy1}" ]
				do
					tempy=`echo ${tempy#*..?}` 	# cut as far as the serial num
					if [ "${tempy1}" != "${tempy}" ]
					then
						echo $tempy | grep "{" > /dev/null 
						if [ "$?" = "0" ]
						then
							# no subkeys
							tempy1=$tempy
							(( x++ ))
						else

							tempy1=`echo ${tempy%% *}`	# take away any trailing info
							pvsn[$x]=${tempy1}
							pvtime[$x]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Enum\USB"$bslash${pidvid[$x]}$bslash${pvsn[$x]} -v`
							if [ "$logging" != "off" ]						
							then
								echo "${pvtime[$x]}" >> $expert_log_location	
							fi
							pvtime[$x]=`echo "${pvtime[$x]%%\]*}"`
							pvtime[$x]=`echo "${pvtime[$x]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
							
							y=$x						
							(( x++ ))
							vid[$x]=${vid[$y]}
							pid[$x]=${pid[$y]}
							pidvid[$x]=${pidvid[$y]}
						fi
					fi
				done
			fi
		done
	((num_vidpid=x-1))
	fi

#### then loop to search for matching serial numbers and assign vids, pids and Enum\USB last accessed date ####

i=0
while [ $i -lt $device_counter ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_vidpid ]
	do
		(( x++ ))
		if [ "${serial_num_[$i]%&*}" = "${pvsn[$x]}" ]
		then
			enumusb_last_insertion_[$i]=${pvtime[$x]}
			if [ "$wpd" = "yes" ]
			then
				if [ "${pvtime[$x]:5:1}" = "0" ]	# date command gets upset with 08 & 09 ?? 
				then
					mon=${pvtime[$x]:6:1}
				else
					mon=${pvtime[$x]:5:2}
				fi
				epoch_pvt=`date +%s -d ${months[$mon]}" "${pvtime[$x]:8:2}", "${pvtime[$x]:0:4}" "${pvtime[$x]:11:8}`
				diff=$(( $epoch_pvt - $epoch_usb ))
				if [[ $diff -lt "20" && $diff -gt "-20" ]] # if there are less than 20 seconds then value may not be device specific
				then
					enumusb_last_insertion_[$i]=${enumusb_last_insertion_[$i]}" Time may not be device specific"
				fi
			fi
			pid_num[$i]=${pid[$x]}
			vid_num[$i]=${vid[$x]}
			if [ -f $vendorid_database ]
			then
				vid_lower=`echo ${vid_num[$i]} | tr '[:upper:]' '[:lower:]'`
				vid_name[$i]=`cat $vendorid_database | grep -n $vid_lower`
				vid_name[$i]=`echo "${vid_name[$i]##*:$vid_lower}"`
				vid_name[$i]=`echo ${vid_name[$i]%%$linefeed*}`
				vid_num[$i]=${vid_num[$i]}" ("${vid_name[$i]}")"
			fi
			x=$num_vidpid
		fi
	done 
done
}


######################################################################
# Add last insertion date from deviceclasses to array from guids     #
# HKLM\System\CurrentControlSet\Control\DeviceClasses\{53f56307....} #
# Assigns:	$last_insertion_[$i]				     #
######################################################################

match_devclass_307_func () {

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}" -v` 
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SYSTEM hive location"
	else
		x=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]		# check to see if string doesn't changed then on last entry
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 	# cut as far as id
			if [ "$temp1" != "$temp_string" ]
			then
				devclass_sn[$x]=`echo ${temp_string%% *}` 	# take id as far as next space
				devclass_sn[$x]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}"$bslash${devclass_sn[$x]} -v` 
				if [ "$logging" != "off" ]						
				then
					echo "${devclass_sn[$x]}" >> $expert_log_location			
				fi
				dctime[$x]=`echo "${devclass_sn[$x]%%\]*}"`
				dctime[$x]=`echo "${dctime[$x]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
				dcsn[$x]=`echo ${devclass_sn[$x]%%\#\{*}` 	# cut out trailing info
				dcsn[$x]=`echo ${dcsn[$x]##*\#}` 		# cut out leading info
				(( x++ ))
			fi
		done
	((num_devclass_sn=x-1))
	fi

#### loop to search for matching serial numbers and assign last accessed date ####

i=0
while [ $i -lt $device_counter ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_devclass_sn ]
	do
		(( x++ ))
		if [ "${serial_num_[$i]}" = "${dcsn[$x]}" ]
			then
			last_insertion_[$i]=${dctime[$x]}
			x=$num_devclass_sn
		fi
	done 
done
}

######################################################################
# Add last insertion date from deviceclasses to array from guids     #
# HKLM\System\CurrentControlSet\Control\DeviceClasses\{53f5630d....} #
# Assigns:	$last_insertion2_[$i]				     #
######################################################################

match_devclass_30d_func () {

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -v` 
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SYSTEM hive location"
	else
		x=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]		# check to see if string doesn't changed then on last entry
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 	# cut as far as id
			if [ "$temp1" != "$temp_string" ]
			then
				devclass_sn[$x]=`echo ${temp_string%% *}` 	# take id as far as next space
				devclass_sn[$x]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"$bslash${devclass_sn[$x]} -v`
				if [ "$logging" != "off" ]						
				then
					echo "${devclass_sn[$x]}" >> $expert_log_location			
				fi 
				dctime[$x]=`echo "${devclass_sn[$x]%%\]*}"`
				dctime[$x]=`echo "${dctime[$x]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
				dcsn[$x]=`echo ${devclass_sn[$x]%%\#\{*}` 	# cut out trailing info
				dcsn[$x]=`echo ${dcsn[$x]##*\#}` 		# cut out leading info
				(( x++ ))
			fi
		done
	((num_devclass_sn=x-1))
	fi

#### loop to search for matching serial numbers and assign last accessed date ####

i=0
while [ $i -lt $device_counter ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_devclass_sn ]
	do
		(( x++ ))
		if [ "${serial_num_[$i]}" = "${dcsn[$x]}" ]
			then
			last_insertion2_[$i]=${dctime[$x]}
			x=$num_devclass_sn
		fi
	done 
done
}

######################################################################
# Add last insertion date from deviceclasses to array from guids     #
# HKLM\System\CurrentControlSet\Control\DeviceClasses\{a5dcbf10....} #
# Assigns :	$last_insert_dc_a5_[$i]				     #
######################################################################


match_devclass_a5_func () {

temp_string=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{a5dcbf10-6530-11d2-901f-00c04fb951ed}" -v` 
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SYSTEM hive location"
	else
		x=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]		# check to see if string doesn't changed then on last entry
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 	# cut as far as id
			if [ "$temp1" != "$temp_string" ]
			then
				devclass_sn[$x]=`echo ${temp_string%% *}` 	# take id as far as next space
				devclass_sn[$x]=`perl $regdump_location $system_hive_location "ControlSet$ccs\Control\DeviceClasses\{a5dcbf10-6530-11d2-901f-00c04fb951ed}"$bslash${devclass_sn[$x]} -v`
				if [ "$logging" != "off" ]						
				then
					echo "${devclass_sn[$x]}" >> $expert_log_location			
				fi 
				dctime[$x]=`echo "${devclass_sn[$x]%%\]*}"`
				dctime[$x]=`echo "${dctime[$x]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
				dcsn[$x]=`echo ${devclass_sn[$x]%%\#\{*}` 	# cut out trailing info
				dcsn[$x]=`echo ${dcsn[$x]##*\#}` 		# cut out leading info
				(( x++ ))
			fi
		done
	((num_devclass_sn=x-1))
	fi

#### loop to search for matching serial numbers and assign last accessed date ####

i=0
while [ $i -lt $device_counter ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_devclass_sn ]
	do
		(( x++ ))
		if [ "${serial_num_[$i]%%&?}" = "${dcsn[$x]}" ] # the dcsn serial number has no &? eg &0 on the end
			then
			last_insert_dc_a5_[$i]=${dctime[$x]}
			x=$num_devclass_sn
		fi
	done 
done
}

######################################################################
# Add last test date from EMDMgmt to array from guids		     #
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\EMDMgmt 	     #
# The first time listed is the time of an attempted test	     #
# If a second time is listed it shows that the test completed	     #
# Assigns:	$last_testtime_[$i]				     #
#		$volume_serial_num_[$i]				     #
#		$volume_sn_hex_[$i]				     #
######################################################################

match_last_testtime_func () {

temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\EMDMgmt" -v` 
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 				# if this is empty 
	then
		echo="Check SOFTWARE hive location"
	else
		x=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]		# check to see if string doesn't changed then on last entry
		do
			temp1=$temp_string
			temp_string=`echo "${temp_string#*..?}"` 	# cut as far as id
			if [ "$temp1" != "$temp_string" ]
			then
				emdmgmt_sn[$x]=`echo "${temp_string%%$linefeed*}"` 	# take id as far as next linefeed
				# do not search volumes other than usbstor devices vista has kanji codes here
				if [ "${emdmgmt_sn[$x]:4:7}" = "USBSTOR" ]
				then
					vol_sn[$x]=`echo ${emdmgmt_sn[$x]##*_}`
					emdmgmt_sn[$x]=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\EMDMgmt"$bslash"${emdmgmt_sn[$x]}" -v` 
					if [ "$logging" != "off" ]						
					then
						echo "${emdmgmt_sn[$x]}" >> $expert_log_location			
					fi
					ltt=`echo ${emdmgmt_sn[$x]##*LastTestedTime (REG_QWORD) = }`
					ltt[$x]=`echo ${ltt:21:2}${ltt:18:2}${ltt:15:2}${ltt:12:2}${ltt:9:2}${ltt:6:2}${ltt:3:2}${ltt:0:2}` 
					if [ ${ltt[$x]} != "0000000000000000" ]
					then
		 				ltt[$x]=`echo $((0x${ltt[$x]}/10000000-11644473600))` #convert wintime to unix time
		 				ltt[$x]=`date -d @${ltt[$x]}`			      #convert unixtime
					else
						ltt[$x]=" "		# if last tested time is zeros just put in a space
					fi 
					emtime[$x]=`echo "${emdmgmt_sn[$x]%%\]*}"`
					emtime[$x]=`echo "${emtime[$x]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
					emtime[$x]=${emtime[$x]}" "${ltt[$x]} 		# add contents (if any)of last tested time
					emsn[$x]=`echo ${emdmgmt_sn[$x]%%\#\{*}` 	# cut out trailing info
					emsn[$x]=`echo ${emsn[$x]##*\#}` 		# cut out leading info
					(( x++ ))
				fi
			fi
		done
	((num_emdmgmt_sn=x-1))
	fi

#### loop to search for matching serial numbers and assign last accessed date ####

i=0
while [ $i -lt $device_counter ]
do
	(( i++ ))
	x=0
	while [ $x -lt $num_emdmgmt_sn ]
	do
		(( x++ ))
		if [ "${serial_num_[$i]}" = "${emsn[$x]}" ]
			then
			last_testtime_[$i]=${emtime[$x]}
			volume_serial_num_[$i]=${vol_sn[$x]}
			volume_sn_hex_[$i]=`echo "ibase=A;obase=16;${volume_serial_num_[$i]}" | bc`
			x=$num_emdmgmt_sn
		fi
	done 
done
}

###################################################################
# Add info from Mountdev to array by stripping MountedDevices	  #
# output as far as a unicode device serial number and checking for#
# an associated drive letter if Vista or later do the same with	  #
# windows portable devices		 		   	  #
# HKLM\System\MountedDevices			     	  	  #
# HKLM\Software\Microsoft\Windows Portable Devices\Devices(vista+)#
# Assigns :	$drive_letter_[$i] (can have multiple entries)    #
#		$vol_id_[$i] 	  (the guid)			  #
###################################################################

match_mountdev_func () {

mountdev_output=`perl $regdump_location $system_hive_location "MountedDevices" -v` 
if [ "$logging" != "off" ]						
then
	echo "$mountdev_output" >> $expert_log_location			
fi
guidmd_output=$mountdev_output 					# leave a string intact for matching guids later
num_dosd=`echo "$mountdev_output" | grep -c "DosDevices"`
x=0
while [ $x -lt $num_dosd ]
do
	(( x++ ))
	mountdev_output=`echo "${mountdev_output#*DosDevices}"`
	mt_drive_letter[$x]=`echo "${mountdev_output:1:1}"`
	drive_data[$x]=`echo "${mountdev_output#*(REG_BINARY) = }"`
	drive_data[$x]=`echo -e "${drive_data[$x]%%\\\\*}"` 	# to hunt for a \ you need \\\\
	i=0
	while [ $i -lt $device_counter ]
	do
		(( i++ ))
		if [ -n "${parentid_unicode_[$i]}" ] 		# if a parent id code exists check for a match in mtdev data
		then
			hit_parentid=`echo ${drive_data[$x]} | grep -c "${parentid_unicode_[$i]}"`
			if [ "$hit_parentid" = "1" ]
			then
				drive_letter_[$i]=${mt_drive_letter[$x]}": (mountdev)"
				i=$device_counter
			fi
		fi
	done 
done
#### checking mountdev for guids, search for s/ns under given long entries ####
num_guids=`echo "$guidmd_output" | grep -c "Volume"`
x=0
while [ $x -lt $num_guids ]
do
	(( x++ ))
	guidmd_output=`echo "${guidmd_output#*Volume}"`
	guid[$x]=`echo "${guidmd_output:0:38}"`
	guid_data[$x]=`echo "${guidmd_output%%\\\\*}"` 
	i=0
	while [ $i -lt $device_counter ]
	do
		(( i++ ))
		if [ -n "${sn_unicode_[$i]}" ] 			# if a serial num exists check for a match in mtdev data
		then
			if [ "$wpd" = "yes" ]
			then
				hit_sn=`echo ${guid_data[$x]} | grep -c "${sn_unicode_[$i]}"`
			else
				if [ -n "${parentid_unicode_[$i]}" ] # make sure parentid_ not blank or it will match everything
				then
				hit_sn=`echo ${guid_data[$x]} | grep -c "${parentid_unicode_[$i]}"`
				fi			
			fi
			if [ "$hit_sn" = "1" ]
			then
				vol_id_[$i]=${guid[$x]}
				i=$device_counter
				hit_sn=0
			fi
		fi
	done 
done

##### If > Vista checking wpd for last drive assignations ####
if [ "$wpd" = "yes" ]
then
#### make a 2d array containing all the drives letters allocated & s/n(s) ####
temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows Portable Devices\Devices" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
	if [ -z "$temp_string" ] 	  
	then
		echo="Check SYSTEM hive location"
	else
		i=1
		temp1="blank"
		while [ "$temp1" != "$temp_string"  ]			# check to see if string doesn't change 
		do
			temp1=$temp_string
			temp_string=`echo ${temp_string#*..?}` 		# cut as far as next key
			if [ "$temp1" != "$temp_string" ]
			then
				port_dev[$i]=`echo ${temp_string%% *}` 	# take id as far as next space
				temp_string_pd[$i]=`perl $regdump_location $software_hive_location "Microsoft\Windows Portable Devices\Devices"$bslash${port_dev[$i]} -v` 			# get the specific portable device(s)
				if [ "$logging" != "off" ]						
				then
					echo "${temp_string_pd[$i]}" >> $expert_log_location			
				fi
				string_empty=`echo ${temp_string_pd[$i]} | grep -c "FriendlyName"`
				if [ $string_empty != 0 ]
				then 
					pd_time[$i]=`echo "${temp_string_pd[$i]%%\]*}"`
					pd_time[$i]=`echo "${pd_time[$i]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
					pd_fname_[$i]=`echo "${temp_string_pd[$i]##*FriendlyName (REG_SZ) = }"`
					pd_fname_[$i]=`echo ${pd_fname_[$i]%%$linefeed*}`
					pd_fname_[$i]=${pd_fname_[$i]}" "${pd_time[$i]}
				else
					pd_fname_[$i]=" "
				fi
			fi
		(( i++ ))
		done
	num_of_pdentries=$i
	fi
#### check the serial numbers in portable devices with main array proper to allocate drive assignations ####
x=0
while [ $x -lt $num_of_pdentries ]
do
	(( x++ ))
	i=0
	while [ $i -lt $device_counter ]
	do
		(( i++ ))
		sn=`echo ${serial_num_[$i]} | tr '[:lower:]' '[:upper:]'` # need to convert case to upper to get matches
		hit_sn=`echo ${temp_string_pd[$x]} | grep -c "$sn"`
		if [ "$hit_sn" = "1" ]
		then
			if [ -z "${drive_letter_[$i]}" ]
			then 
				drive_letter_[$i]=${pd_fname_[$x]}
			else
				add_if_diff=`echo ${drive_letter_[$i]} | grep -c "${pd_fname_[$x]}"`
				if [ "$add_if_diff" -lt "1" ] 		# if already in string don't add it
				then					# again two types ## or ?? entries in Vista
					drive_letter_[$i]=${drive_letter_[$i]}"\n\r\t\t: "${pd_fname_[$x]}
				fi					# the \n etc above are for screen formatting
			fi
		i=$device_counter	
		fi
	done
done

fi
}

#############################################
#  get first install date and time of usb   #
#  from setupapi log files		    #
#############################################

usb_first_install_func () {
if [ "$logging" != "off" ]						
then
	if [ -f $setupapi_location ]
	then
		cat $setupapi_location >> $expert_log_location
	fi			
fi
if [ "$wpd" = "yes" ] #if its >= Vista
then
	i=0
	while [ $i -lt $device_counter ]
	do
		(( i++ ))
		firstbit=`grep "${serial_num_[$i]}\|Section start" $setupapi_location` 	  # get the lines we want
		firstbit=`grep -A 2 "${serial_num_[$i]}]" $setupapi_location` 	  	  # get the lines we want
		firstbit=`echo "${firstbit##*Section start }"` 				  # cut out leading info
		if [ "${firstbit:0:1}" != "" ]
		then
		first_installed_[$i]=`echo "${firstbit:0:23} (Local Time)"` 		  # cut out trailing info
		else
		first_installed_[$i]="not recorded in the given setupapi.log"
		fi
	done
else
#### the xp bit ####
	i=0
	while [ $i -lt $device_counter ]
	do
		(( i++ ))
		setupapi_data=`cat $setupapi_location`
		caps_sn=`echo ${serial_num_[$i]} | tr '[:lower:]' '[:upper:]'`
		string_empty=`grep -c $caps_sn $setupapi_location`
		if [ $string_empty != 0 ]
		then 
			setupapi_data=`grep -A 1 $caps_sn $setupapi_location` 	# -A gives you the next line too with date
			setupapi_data=`echo "${setupapi_data##*[}"` 		# cut out up to [
			first_installed_[$i]=`echo "${setupapi_data:0:19} (Local Time)"`
		else
			first_installed_[$i]="not recorded in the given setupapi.log"
		fi
	done
fi
}
 
##################################################################################
# Check for mountpoint2 matches in ntuser.dats (if they exist) and username 	 #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2 	    	 #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer (xp) 			 #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders (vista+) #
# Assigns:	$username_[$i]							 # 
##################################################################################

ntuser_mp2_func () {

#### check to see if there are any ntuser.dats in the default dir ####
ntulist=`find $default_location -iname ntuser*`
num_user_hives=0
while [ -n "$ntulist" ]
do
	(( num_user_hives++ ))
	ntu_hive[$num_user_hives]=`echo "${ntulist%%$linefeed*}"`
	ntulist=`echo "${ntulist#*${ntu_hive[$num_user_hives]}}"`
	ntulist=`echo "${ntulist#*$linefeed}"`
done
#### if there are userhives inspect mountpoint2 keys for device volume guids ####
if [ $num_user_hives -gt "0" ]
then
	#### populate mp2[?] for each hive ####
	x=0
	while [ $x -ne $num_user_hives ]
	do
		(( x++ ))
		mp2[$x]=`perl $regdump_location ${ntu_hive[$x]} "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" -v 2>/dev/null`
		if [ "$logging" != "off" ]						
		then
			echo "${mp2[$x]}" >> $expert_log_location			
		fi
	done

	i=0	# number of usbdevices
	x=0	# number of userhives
	while [ $i -ne $device_counter ]
	do
		(( i++ ))
		if [ "${vol_id_[$i]:0:1}" = "{" ]
		then
			x=0
			#### search thru the mounpoint2s in all hives for it ####
			while [ $x -ne $num_user_hives ]
			do
				(( x++ ))
				echo ${mp2[$x]}	| grep ${vol_id_[$i]} > /dev/null
				if [ $? = "0" ]
				then
					temp[$i]=`perl $regdump_location ${ntu_hive[$x]} "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"$bslash${vol_id_[$i]} -v`
					if [ "$logging" != "off" ]						
					then
						echo "${temp[$i]}" >> $expert_log_location			
					fi
					mp2_time[$i]=`echo "${temp[$i]%%\]*}"`
					mp2_time[$i]=`echo "${mp2_time[$i]##*\[}" | tr "T" " " | tr "Z" " "`"(UTC)"
					#### check if xp or vista + to get username from hive ####
					if [ "$wpd" != "yes" ] 			
					then # it's xp
						mp2_uname[$i]=`perl $regdump_location ${ntu_hive[$x]} "Software\Microsoft\Windows\CurrentVersion\Explorer" -v`
						if [ "$logging" != "off" ]						
						then
							echo "${mp2_uname[$i]}" >> $expert_log_location			
						fi
						mp2_uname[$i]=`echo "${mp2_uname[$i]##*Logon User Name (REG_SZ) = }"`
						mp2_uname[$i]=`echo "${mp2_uname[$i]%%$linefeed*}"`	

					else # it's vista+
						mp2_uname[$i]=`perl $regdump_location ${ntu_hive[$x]} "Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -v`
						if [ "$logging" != "off" ]						
						then
							echo "${mp2_uname[$i]}" >> $expert_log_location			
						fi
						mp2_uname[$i]=`echo "${mp2_uname[$i]##*CD Burning (REG_SZ) = }"`
						mp2_uname[$i]=`echo "${mp2_uname[$i]#*C:?Users?}"`
						mp2_uname[$i]=`echo "${mp2_uname[$i]%%\\\\*}"`


					fi
					mp2_uname[$i]=${mp2_uname[$i]}" "${mp2_time[$i]}
					#### this is to check in case multiple users used the same device ?####
					if [ -z "${username_[$i]}" ]
					then 
						username_[$i]=${mp2_uname[$i]}
					else
						username_[$i]=${username_[$i]}"\n\r\t\t: "${mp2_uname[$i]}
						# the \n etc above are for screen formatting
					fi
				fi
			done
		fi
	done

else
	echo "No user hives found in default directory usb devices can't be associated with usernames"
fi
}

#########################################################
# Check for .lnk files and any volume id associations	#
# Assigns:	$assoc_lnks[$i]				#
#########################################################

link_file_check () {
temp=`ls $lnkpath`
p=$IFS
IFS=$'\n'
for thefile in `echo "$temp"`
do
	hexfile=`xxd -u -ps $lnkpath"/"$thefile`
	## loop thru all the volumeids to search for a match
	i=0
	while [ "$i" -lt "$device_counter" ]
	do
		(( i++ ))
		if [ "${volume_serial_num_[$i]}" != "" ]
		then 
			endian_sn=${volume_sn_hex_[$i]:6:2}${volume_sn_hex_[$i]:4:2}${volume_sn_hex_[$i]:2:2}${volume_sn_hex_[$i]:0:2}
			hit=`echo $hexfile | grep -c "$endian_sn"`
			if [ $hit -gt "0" ]
			then
				if [ -z ${assoc_lnks[$i]} ]
				then
					assoc_lnks[$i]=$thefile
				else
					assoc_lnks[$i]=${assoc_lnks[$i]}"\n\r\t\t: "$thefile
				fi
				i=$device_counter
			fi
		fi
	done
done 
IFS=$p
}

#############################################
#         Output usb info to screen         #
#############################################

output_to_screen_func () {
if [ "$logging" = "off" ]						
then
	log_location="/dev/null"
fi
i=0
echo "There are "$device_counter" USB device(s) associated with this system ("$comp_name")" | tee $log_location
echo | tee -a $log_location
until [ $i -eq $device_counter ]
do
	(( i++ ))
	echo "Serial num/iid	: "${serial_num_[$i]} | tee -a $log_location		# output to screen and file
	echo "Long name     	: "${long_name_[$i]} | tee -a $log_location		# -a is to append
	echo "Friendly name 	: "${friendly_name_[$i]} | tee -a $log_location
	echo "Last in dc 307	: "${last_insertion_[$i]} | tee -a $log_location
	echo "Last in dc 30d	: "${last_insertion2_[$i]} | tee -a $log_location
	echo "Last in enumusb	: "${enumusb_last_insertion_[$i]} | tee -a $log_location
	echo "Last in dc a5	: "${last_insert_dc_a5_[$i]} | tee -a $log_location
	if [ "$wpd" = "yes" ] #only print this if its Vista+
	then
		echo "Last test time	: "${last_testtime_[$i]} | tee -a $log_location
	fi
	echo "Vendor ID       : "${vid_num[$i]} | tee -a $log_location
	echo "Product ID	: "${pid_num[$i]} | tee -a $log_location
	echo -e "Drive\Volume 	: "${drive_letter_[$i]} | tee -a $log_location
	echo "Volume GUID   	: "${vol_id_[$i]} | tee -a $log_location
	if [ "$wpd" = "yes" ] #only print this if its Vista+
	then
		if [ "${volume_serial_num_[$i]}" != "" ]
		then
		   echo "Volume s/n	: "${volume_serial_num_[$i]}" (0x"${volume_sn_hex_[$i]}")" | tee -a $log_location
		else
		   echo "Volume s/n	: " | tee -a $log_location
		fi
	fi
	echo -e ".lnk files	: "${assoc_lnks[$i]} | tee -a $log_location
	echo "First install	: "${first_installed_[$i]} | tee -a $log_location
	echo -e "Username	: "${username_[$i]} | tee -a $log_location
	if [ "$wpd" != "yes" ] #only print this if its XP
	then
		echo "ParentID Prefix	: "${parentid_pf_[$i]} | tee -a $log_location
	fi
	echo | tee -a $log_location
done
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
	-K) lnkpath=$2 ; shift 2;;
	*) shift 1;;
	esac 
done

# if the hive locations are empty set them to the defaults #

#default_location="../hives/" 	# if you change this keep the trailing backslash
if [ -z $system_hive_location ]
then
	system_hive_location=$default_location"/system"
	if [ ! -f "$system_hive_location" ]				# Vista + generally system is SYSTEM ?
	then
		system_hive_location=$default_location"/SYSTEM"
	fi
fi
if [ -z $setupapi_location ]
then
	setupapi_location=$default_location"/setupapi.dev.log"
	if [ ! -f "$setupapi_location" ]				# xp is in setupapi.log w/o the .dev
	then
		setupapi_location=$default_location"/setupapi.log"
	fi
fi
if [ -z $lnkpath ]
then
	lnkpath=$default_location"/lnk"
	if [ ! -d "$lnkpath" ]				# xp is in setupapi.log w/o the .dev
	then
		echo "link file path does not exist, link files will not be examined"
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

if [ ! -f "$setupapi_location" ]
	then
		clear
		echo "setupapi not found: first install date will not be reported"
fi


#### if args are valid run functions ####
current_control_set_func
pull_out_compname_func
pull_out_winver_func
pull_out_usbstor_func
pull_out_pidvid_func
match_devclass_307_func
match_devclass_30d_func
match_devclass_a5_func
if [ "$wpd" = "yes" ] # only do this if O/S is vista or above
then
	match_last_testtime_func
fi
match_mountdev_func
ntuser_mp2_func
if [ -f "$setupapi_location" ]
	then
	usb_first_install_func
fi
if [ -d $lnkpath ]
then
	link_file_check
fi
output_to_screen_func
exit


