#!/bin/bash 
###############################################
# Utility to present information about        #
# users in a clear and related manner. 	      #
# Jacky Fox 2012 			      #
# Dependancies regdump.pl                     #
###############################################

#############################################
# variable settings			    #
#############################################

regdump_location="/usr/local/bin/regdump.pl"
expert_log_location="user_expert.log" # location of unfiltered output for evidential purposes
log_location="user.log"	 	      # location of sorted and related user log
device_counter=1
long_name_1="not blank"
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
#echo "	-A (path and name of setupapi.log file)	-A ../hives/setupapi.dev.log"
echo "	-W (path and name of Software hive)	-W /samples/software"
echo "	-D (default location of hives)		-D xphives"
#echo "	-C (path and name of Security hive)	-C ../hives/SECURITY"
echo "	-M (path and name of the SAM)		-M ../hives/SAM"
echo "	-E (switch off expert logs)		-E off"
echo "	-L (give explicit path for logs)	-L /logdir"
exit
}


###################################################################
# Check current control set number  	  			  #
# HKLM\SYSTEM\Select						  #
# Assigns:	$ccs						  #
###################################################################

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
# Get the windows version from		      			#
# HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName #
# Assigns:	$win_ver					#
#		$wpd						#
#		$win7						#
#################################################################

get_winver_func () {

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
	echo $win_ver | grep -q "Windows 7\|Windows Vista" 	# check if windows is >= Vista
	if [ $? = "0" ]						
	then							
		wpd="yes"
	fi
	echo $win_ver | grep -q "Windows 7" 	# check if windows is 7
	if [ $? = "0" ]						
	then							
		win7="yes"
	fi
}

##################################################
# Get all the usernames recorded in the registry #
# HKLM\SAM\SAM\Domains\Account\Users\Names       #
# Assigns: 	$name[$i]			 #
#		$name_rid[$i]		         # 
#		$rid[$i] (in hex)		 #
##################################################

get_usernames_func () {

temp_string=`perl $regdump_location $sam_location "SAM\Domains\Account\Users\Names" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 					# if this is empty 
then
	echo="Check SAM hive location"
else
	i=0
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
		then
			(( i++ ))
			name[$i]=${eachline##*..?}
			name_rid[$i]=`perl $regdump_location $sam_location "SAM\Domains\Account\Users\Names$bslash${name[$i]}" -v`
		  	if [ "$logging" != "off" ]						
		  	then
				echo "${name_rid[$i]}" >> $expert_log_location
		  	fi
			name_rid[$i]=`echo "${name_rid[$i]#*(REG_}"`
			name_rid[$i]=`echo "${name_rid[$i]%%)*}"` 
			temp=$(echo "obase=16;${name_rid[$i]}" | bc)
			rid[$i]="00000000"
			rid[$i]=${rid[$i]:0:(8-${#temp})}$temp # 8 digit hex number 
		fi
	done
	IFS=$p
	((num_users=i))
fi
}

#################################################################
# get the profilelists from the registry from         		#
# HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Profilelist	#
# Assigns : 	$profile_rid[$z]				#
#		$profile_image_path[$z]				#
#		$profile_ntu_loc[$z]				#
#		$profile_rid[$z]				#
#	note these are not assigned to users yet hence $z	#	
#################################################################

profile_list_func () {

temp_string=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\Profilelist" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
z=0
p=$IFS
IFS=$'\n'
for eachline in `echo "$temp_string"`				
do
	if [ "${eachline:0:2}" = ".." ]				# if the line holds a profile
	then
		(( z++ ))
		profile_list[$z]=${eachline##*..?}
		profile_rid[$z]=`echo ${profile_list[$z]##*-}`
		profile_sid[$z]=`perl $regdump_location $software_hive_location "Microsoft\Windows NT\CurrentVersion\Profilelist$bslash${profile_list[$z]}" -v`
		if [ "$logging" != "off" ]						
		then
			echo "${profile_sid[$z]}" >> $expert_log_location
		fi
		profile_image_path[$z]=`echo "${profile_sid[$z]##*ProfileImagePath (REG_EXPAND_SZ) = }"`
		profile_image_path[$z]=`echo ${profile_image_path[$z]%%$linefeed*}`
		if [ "$wpd" = "yes" ]	# this bit sets the expected ntuser.dat file name for each profile
		then
			profile_ntu_loc[$z]=`echo "NTUSER.DAT."${profile_image_path[$z]##*\\\\Users\\\\}`	# vista+
		else
			profile_ntu_loc[$z]=`echo "NTUSER.DAT."${profile_image_path[$z]##*Settings\\\\}`	# xp
		fi
	fi
done
IFS=$p
((num_profiles=z))
}

######################################################################
# Use the RIDs to get the F values (timestamps) for each user	     #
# HKLM\SAM\SAM\Domains\Account\Users\{RID}  			     #
# Assigns : 	$last_logon[$i]					     #
#		$password_change[$i]				     #
#		$account_expires[$i]				     #
#		$failed_logon[$i]				     #
#		$num_logons[$i]					     #
#		$ac_enabled[$i]					     #
# if the user has logged in then also get the following		     #
#		$user_profile_folder[$i]		 	     #
######################################################################

get_timestamps_func () {

i=0
while [ $i -lt $num_users ]
do
	(( i++ ))
	temp_string[$i]=`perl $regdump_location $sam_location "SAM\Domains\Account\Users\$bslash${rid[$i]}" -v`
	if [ "$logging" != "off" ]						
	then
		echo "${temp_string[$i]}" >> $expert_log_location
	fi
	f_value[$i]=`echo "${temp_string[$i]##*F (REG_BINARY) = }"`
	f_value[$i]=`echo ${f_value[$i]%%$linefeed*} | tr -d " "`
	x=30	# marker for start of this value in the "F" value
	last_logon[$i]=${f_value[$i]:($x):2}${f_value[$i]:($x-2):2}${f_value[$i]:($x-4):2}${f_value[$i]:($x-6):2}${f_value[$i]:($x-8):2}${f_value[$i]:($x-10):2}${f_value[$i]:($x-12):2}${f_value[$i]:($x-14):2}
	if [ "${last_logon[$i]}" = "0000000000000000" ]
	then
		last_logon[$i]="No logon recorded"
	else
		last_logon[$i]=`echo $((0x${last_logon[$i]}/10000000-11644473600))`   	#convert windowstime to unix time
		last_logon[$i]=`date -d @${last_logon[$i]}`				#convert unixtime 
		z=0
		while [ $z -lt $num_profiles ] #check the profiles for matching rids to assign userprofilefolder
		do
			(( z++ ))
			if [ ${name_rid[$i]} = ${profile_rid[$z]} ]
			then
				user_profile_folder[$i]=${profile_image_path[$z]}
				user_ntuser_loc[$i]=${profile_ntu_loc[$z]}
			fi
		done	
	fi
	x=62	# marker for start of this value in the "F" value
	password_change[$i]=${f_value[$i]:($x):2}${f_value[$i]:($x-2):2}${f_value[$i]:($x-4):2}${f_value[$i]:($x-6):2}${f_value[$i]:($x-8):2}${f_value[$i]:($x-10):2}${f_value[$i]:($x-12):2}${f_value[$i]:($x-14):2}
	if [ "${password_change[$i]}" = "0000000000000000" ]
	then
		password_change[$i]="Never"
	else
		password_change[$i]=`echo $((0x${password_change[$i]}/10000000-11644473600))`  	
		password_change[$i]=`date -d @${password_change[$i]}`	
	fi
	x=78	# marker for start of this value in the "F" value
	account_expires[$i]=${f_value[$i]:($x):2}${f_value[$i]:($x-2):2}${f_value[$i]:($x-4):2}${f_value[$i]:($x-6):2}${f_value[$i]:($x-8):2}${f_value[$i]:($x-10):2}${f_value[$i]:($x-12):2}${f_value[$i]:($x-14):2}
	if ( [ "${account_expires[$i]}" = "7FFFFFFFFFFFFFFF" ] || [ "${account_expires[$i]}" = "7fffffffffffffff" ] )
	then
		account_expires[$i]="Does not expire"
	else
		if [ "${account_expires[$i]}" = "0000000000000000" ]
		then
			account_expires[$i]="No expiry set"
		else
		account_expires[$i]=`echo $((0x${account_expires[$i]}/10000000-11644473600))`  	
		account_expires[$i]=`date -d @${account_expires[$i]}`
		fi
	fi
	x=94	# marker for start of this value in the "F" value
	failed_logon[$i]=${f_value[$i]:($x):2}${f_value[$i]:($x-2):2}${f_value[$i]:($x-4):2}${f_value[$i]:($x-6):2}${f_value[$i]:($x-8):2}${f_value[$i]:($x-10):2}${f_value[$i]:($x-12):2}${f_value[$i]:($x-14):2}
	if [ "${failed_logon[$i]}" = "0000000000000000" ]
	then
		failed_logon[$i]="Never"
	else
	failed_logon[$i]=`echo $((0x${failed_logon[$i]}/10000000-11644473600))`  	
	failed_logon[$i]=`date -d @${failed_logon[$i]}`
	fi
	num_logons[$i]=`echo ${f_value[$i]:134:2}${f_value[$i]:132:2} | tr '[:lower:]' '[:upper:]'` # bc likes uppercase
	num_logons[$i]=`echo "ibase=16;obase=A;${num_logons[$i]}" | bc`
	ac_enabled[$i]=${f_value[$i]:113:1}
	case ${ac_enabled[$i]} in
	[0,2,6,8,a,c,e,A,C,E]) ac_enabled[$i]="Yes" ;; 
	4) ac_enabled[$i]="Yes (Password required)" ;;
	[1,3,5,7,b,d,f,B,D,F]) ac_enabled[$i]="No" ;;
	*) ac_enabled[$i]="Unknown" ;;
	esac 
done
}

##################################################
# Get all the groupnames recorded in the registry#
# HKLM\SAM\SAM\Domains\Builtin\Aliases\Names     #
# Assigns : 	$groupname[$i]			 #
#		$groupname_rid[$i]		 # 
#		$group_rid[$i] (in hex)		 #
#		$num_groups			 #
##################################################

get_groupnames_func () {

temp_string=`perl $regdump_location $sam_location "SAM\Domains\Builtin\Aliases\Names" -v`
if [ "$logging" != "off" ]						
then
	echo "$temp_string" >> $expert_log_location			
fi
if [ -z "$temp_string" ] 	 					# if this is empty 
then
	echo="Check SAM hive location"
else
	i=0
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
		then
			(( i++ ))
			groupname[$i]=${eachline##*..?}
			groupname_rid[$i]=`perl $regdump_location $sam_location "SAM\Domains\Builtin\Aliases\Names$bslash${groupname[$i]}" -v`
			if [ "$logging" != "off" ]						
			then
				echo "${groupname_rid[$i]}" >> $expert_log_location
			fi
			groupname_rid[$i]=`echo "${groupname_rid[$i]#*(REG_}"`
			groupname_rid[$i]=`echo "${groupname_rid[$i]%%)*}"` 
			temp=$(echo "obase=16;${groupname_rid[$i]}" | bc)
			group_rid[$i]="00000000"
			group_rid[$i]=${group_rid[$i]:0:(8-${#temp})}$temp # 8 digit hex number
		fi
	done
	IFS=$p
	((num_groups=i))
fi
}

######################################################################
# Get username RIDs for members of each group			     #
# HKLM\SAM\SAM\Domains\Builtin\Aliases\{RID}  			     #
# Assigns: 	$num_members[$i]				     #
#		$offset_to_sids[$i]				     #
#		$group_members_rid[$i$y]			     #
#		$group_members_name[$i$y]			     #
#		$memberof[$z] (user specific list of groups) 	     #
######################################################################

get_members_func () {

i=0
while [ $i -lt $num_groups ]
do
	(( i++ ))
	temp_string[$i]=`perl $regdump_location $sam_location "SAM\Domains\Builtin\Aliases\$bslash${group_rid[$i]}" -v`
	if [ "$logging" != "off" ]						
	then
		echo "${temp_string[$i]}" >> $expert_log_location
	fi
	c_value[$i]=`echo "${temp_string[$i]##*C (REG_BINARY) = }"` 
	c_value[$i]=`echo ${c_value[$i]%%$linefeed*} | tr -d " "`
	x=102	# marker for position to extract little endian data 
	num_members[$i]=${c_value[$i]:($x):2}${c_value[$i]:($x-2):2}${c_value[$i]:($x-4):2}${c_value[$i]:($x-6):2}
	x=86	# marker for position to extract little endian data 
	offset_to_sids[$i]=${c_value[$i]:($x):2}${c_value[$i]:($x-2):2}${c_value[$i]:($x-4):2}${c_value[$i]:($x-6):2}
	offset_to_sids[$i]=$((0x${offset_to_sids[$i]}+0x34)) # get the offset to the 1st sid in decimal
	y=0
	while [ $y -lt ${num_members[$i]} ]	# populate the array with users
	do
		(( y++ ))	
		x=$((((${offset_to_sids[$i]}*2))+(($y*56))-8))
		if [ ${groupname[$i]} = "Users" ]
		then
			if [ $y -lt "3" ]	# to accomodate the two unrecorded users once
			then
				y=$((y+2))
			else
				x=$((x-112))	# move the marker back to pick up the right RID
			fi
			x=$((x+48))		# in users the sids are recorded later
		fi
		group_members_rid[$i$y]=${c_value[$i]:($x+6):2}${c_value[$i]:($x+4):2}${c_value[$i]:($x+2):2}${c_value[$i]:$x:2} 
		group_members_rid[$i$y]=`echo ${group_members_rid[$i$y]} | tr '[:lower:]' '[:upper:]'`	
		z=0
		while [ $z -lt $num_users ]
		do
			(( z++ ))
			if [ "${group_members_rid[$i$y]}" = "${rid[$z]}" ] # if the rids match 
			then
				group_members_name[$i$y]=${name[$z]}	   # add the usernames to the group array
				memberof[$z]=${memberof[$z]}": "${groupname[$i]}"\n\r\t\t\t" # add the groupname to the user
			fi
		done		
 
	done
done
}

######################################################################
# Scan ntuser hives given and tries to allocate them to a username   #
# Assigns: 	$ntu_files					     #
#		$num_ntuser_hives				     #
#		$ntu_loc[$z]					     #
#		$ntu_name[$z]					     #
######################################################################

get_ntuser_hives_func () {

#### get the ntuser.dat files that are there and put them in an array ####
ntu_files=`find $default_location -maxdepth 1 -iname NTUSER.DA*`
num_ntuser_hives=`echo "$ntu_files" | grep -ic "NTUSER.DAT"`	# ic = ignore case and count
z=0
temp=$ntu_files
p=$IFS
IFS=$'\n'
for eachline in `echo "$temp"`				
do
	(( z++ ))
	ntu_loc[$z]=$eachline
done
IFS=$p
#### allocate users to ntuser.dat files if possible ####
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	i=0
	while [ $i -lt $num_users ]
	do
		(( i++ ))
		if [ "${ntu_loc[$z]}" = "$default_location/${user_ntuser_loc[$i]}" ]
		then
			ntu_name[$z]=${name[$i]}
			ntu_profile_folder[$z]=${user_profile_folder[$i]}
			i=$num_users	#stop
		fi
		if ( [ $i = $num_users ] && [ -z "${ntu_name[$z]}" ] ) # if you've checked all the users and no match
		then
			ntu_name[$z]="Unable to associate with a username"
			ntu_profile_folder[$z]="Unrecorded"
		fi
	done
done
}

##############################################################################
# Get shell folders						     	     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders #
# Assigns:	$ntu_user_shell_folders[$z]				     #
# Get recent docs mrulists - this function get the extentions used   	     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs 	     #
# Assigns:	$rdocs_num_ext[$z] 					     #
#		$rdocs_ext[$z$i] ($z indicates user $i indicates ext #)	     #
##############################################################################

get_ntuser_data_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -v`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	ntu_user_shell_folders[$z]=`echo "$temp_string" | sed -e 's/(REG_EXPAND_SZ) //'` 
	ntu_user_shell_folders[$z]="${ntu_user_shell_folders[$z]##*]}"
################### start of recent docs #################################
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	i=0
	rdocs_date[$z]=${temp_string%%]*}	
	rdocs_date[$z]=`echo ${rdocs_date[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)"
	if [ "${rdocs_date[$z]}" = "(UTC)" ]
	then 
		rdocs_date[$z]="No recent docs MRU associated with this user"
	fi
	rdocs_ext[$z$i]=${temp_string%%]*}	# $z$i = $z0 to root mru
#################### extract MRU for each extention #######################	
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds an extention subkey
		then
			(( i++ ))
			rdocs_ext[$z$i]=${eachline##*..?}
			rdocs_name[$z$i]=${rdocs_ext[$z$i]}
			rdocs_ext[$z$i]=`perl $regdump_location ${ntu_loc[$z]} "Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs$bslash${rdocs_ext[$z$i]}" -v`
			last_folder[$z$i]=${rdocs_ext[$z$i]}	# set the last folder each time so that temp_string can
		  	if [ "$logging" != "off" ]		# be truncated to isolate general mru list from .ext(s) 					
		  	then
				echo "${rdocs_ext[$z$i]}" >> $expert_log_location
		  	fi

		fi
	done
	IFS=$p
	((rdocs_num_exts[$z]=i))
	rdocs_ext[$z"0"]=${rdocs_ext[$z"0"]#*${last_folder[$z$i]}}	# get rid of the folders in the mru root string
done
}

###########################################################
# Goes through each hive, pulls up each mrulist extention #
# and generates and converts each MRU list to ascii	  #
# Assigns:	$mrulist_date[$z$i]			  #
#		$mrulist[$z]				  #
###########################################################

get_ntuser_mrulist_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	mrustring=""
	i=0
	while [ $i -le ${rdocs_num_exts[$z]} ]
	do
		exist=`echo "${rdocs_ext[$z$i]}" | grep -c "MRUListEx"`
		if [ $exist -gt "0" ]	# if there is an MRUList
		then
			mrulist_date[$z$i]=${rdocs_ext[$z$i]%%]*}  
			mrulist_date[$z$i]=`echo ${mrulist_date[$z$i]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
			mrulist[$z$i]=`echo ${rdocs_ext[$z$i]}|awk -F'MRUListEx \(REG_BINARY\) = |ff ff ff ff' '{print $2}'`
			mrustring=$mrustring${rdocs_name[$z$i]}" MRU List - "${mrulist_date[$z$i]}$crlf
			y=0	# counter for number of mru entries
			x=0	# marker for position to extract little endian data nb 1 space between data
			finish="no"
			while [ $finish = "no" ]
			do
				mru_num[$y]=${mrulist[$z$i]:($x+9):2}${mrulist[$z$i]:($x+6):2}${mrulist[$z$i]:($x+3):2}${mrulist[$z$i]:$x:2}
				x=$x+12 # move to the next entry
				if [ -z "${mru_num[$y]}" ]	# if the last mru entry didn't exist
				then
					no_entries[$z$i]=$y
					finish="yes"
				else
					mru_num[$y]=`echo ${mru_num[$y]}| tr '[:lower:]' '[:upper:]'`
					mru_num[$y]=`echo "ibase=16;obase=A;${mru_num[$y]}" | bc` # convert to decimal
					mru_data[$y]=${rdocs_ext[$z$i]##*${mru_num[$y]} (REG_BINARY) = } # cut to start
					mru_data[$y]=${mru_data[$y]%%00 00 00*} # cut to first 00 00 to get UTF-16 name
					# loop to convert to text note last unicode only 2 chars long echo -e "\u????" ok 
					mru_data_length[$y]=$((((${#mru_data[$y]}+4))/6)) # get the number of chars
					j=0
					name=""
					while [ $j -lt ${mru_data_length[$y]} ]
					do
						# turn 45 00 into 0045
						nextbit=${mru_data[$y]:(((($j*3))+3*(($j+1)))):2}${mru_data[$y]:(($j*6)):2} 
						name=$name`echo -e "\u"$nextbit`
						(( j++ ))
					done
					mrustring=$mrustring" "$name$crlf
					(( y++ ))
				fi
			done
		fi
		(( i++))
	done
	mru_list[$z]=$mrustring
done
}

######################################################################
# Get media player mrulist					     #
# HKCU\Software\Microsoft\MediaPlayer\Player\RecentFileList	     #
# Assigns: 	$mediaplayer[$z] for each user hive		     #
######################################################################

get_ntuser_mediaplayer_mru_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\MediaPlayer\Player\RecentFileList" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		mediaplayer[$z]="There are no entries associated with this user"
	else
		mediaplayer[$z]=${temp_string%%]*} 
 		mediaplayer[$z]=`echo ${mediaplayer[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			firstbit=${eachline%%\(*}
			lastbit=${eachline##* = }
			mediaplayer[$z]=${mediaplayer[$z]}$crlf$firstbit$lastbit
		done
		IFS=$p
	fi
done
}
######################################################################
# Get typed url list						     #
# HKCU\Software\Microsoft\Internet Explorer\TypedURLs		     #
# Assigns: 	$urllist[$z] for each user hive			     #
######################################################################

get_ntuser_typed_urls_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Internet Explorer\TypedURLs" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		urllist[$z]="There are no entries associated with this user"
	else
		urllist[$z]=${temp_string%%]*} 
 		urllist[$z]=`echo ${urllist[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			firstbit=${eachline%%\(*}
			firstbit=${firstbit##*url}
			lastbit=${eachline##* = }
			urllist[$z]=${urllist[$z]}$crlf" "$firstbit$lastbit
		done
		IFS=$p
	fi
done
}

######################################################################
# Get Userassist strings, do ROT13 "decryption"			     #
# Window 7							     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist #
#   \{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count		     #
# Assigns: 	$uassist_intexp[$z] for each user hive		     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist #
#   \{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count		     #
# Assigns:	$uassist_desktop[$z]				     #
# XP & Vista (subtracts 5 from some counts)			     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist #
#   \{5E6AB780-7743-11CF-A12B-00AA004AE837}\Count		     #
# Assigns:	$uassist_intexp[$z]				     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist #
#   \{75048700-EF1F-11D0-9888-006097DEACF9}\Count		     #
# Assigns:	$uassist_desktop[$z]				     #
######################################################################

get_userassist_func () {

if [ "$win7" = "yes" ]	# win 7 only #
then
	z=0
	while [ $z -lt $num_ntuser_hives ]
	do
		(( z++ ))
		temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count" -v 2>/dev/null`
		if [ "$logging" != "off" ]						
		then
			echo "$temp_string" >> $expert_log_location			
		fi
		if [ -z "$temp_string" ]
		then
			uassist_intexp[$z]="There are no entries associated with this user"
		else
			uassist_intexp[$z]=${temp_string%%]*} 
 			uassist_intexp[$z]=`echo ${uassist_intexp[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
			temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
			p=$IFS
			IFS=$'\n'
			for eachline in `echo "$temp_string"`				
			do
				rot13=""
				firstbit=${eachline%% \(*}
				firstbit=${firstbit##*\}}
				firstbit=`echo $firstbit | xxd -u -ps` 	# | tr -d " "`
				firstbit=`echo $firstbit | tr -d " "`
				len_firstbit=$((${#firstbit}/2))
				x=0
				while [ $x -lt $len_firstbit ]		# do ROT-13
				do
					char=${firstbit:($x*2):2}
					case $char in
					41|42|43|44|45|46|47|48|49|4A|4B|4C|4D) dechar=`printf "%X" $((0x$char+0xD))`;;
					4E|4F|50|51|52|53|54|55|56|57|58|59|5A) dechar=`printf "%X" $((0x$char-0xD))`;;
					61|62|63|64|65|66|67|68|69|6A|6B|6C|6D) dechar=`printf "%X" $((0x$char+0xD))`;;
					6E|6F|70|71|72|73|74|75|76|77|78|79|7A) dechar=`printf "%X" $((0x$char-0xD))`;; 
					*) dechar=$char;;
					esac 
					rot13=$rot13$dechar
					(( x++ ))
				done
				firstbit=`echo $rot13 | xxd -r -p`	
				lastbit=`echo ${eachline##* = } | tr -d " "`
				uacount=${lastbit:14:2}${lastbit:12:2}${lastbit:10:2}${lastbit:8:2}
				uacount2=${lastbit:22:2}${lastbit:20:2}${lastbit:18:2}${lastbit:16:2}
				uatime=${lastbit:134:2}${lastbit:132:2}${lastbit:130:2}${lastbit:128:2}${lastbit:126:2}${lastbit:124:2}${lastbit:122:2}${lastbit:120:2}	# uatime = timestamp of last usage
				input_string=$uacount	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount=$output_string	# win 7 uacount seems to be # uses in current month not total
				uacount=`echo "ibase=16;obase=A;$uacount" | bc`
				input_string=$uacount2	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount2=$output_string
				uacount2=`echo "ibase=16;obase=A;$uacount2" | bc`
				if [ "$uatime" = "0000000000000000" ]
				then
					uatime=""
				else
					uatime=`echo $((0x$uatime/10000000-11644473600))`  #convert windowstime to unix time
					uatime=`date -d @$uatime 2>/dev/null`		   #convert unixtime 
				fi
				uassist_intexp[$z]=${uassist_intexp[$z]}"$lfcr"" "$firstbit" ("$uacount") "" ("$uacount2") "$uatime
			done
			IFS=$p
		fi
		temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count" -v 2>/dev/null`
		if [ "$logging" != "off" ]						
		then
			echo "$temp_string" >> $expert_log_location			
		fi
		if [ -z "$temp_string" ]
		then
			uassist_desktop[$z]="There are no entries associated with this user"
		else
			uassist_desktop[$z]=${temp_string%%]*} 
 			uassist_desktop[$z]=`echo ${uassist_desktop[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
			temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
			p=$IFS
			IFS=$'\n'
			for eachline in `echo "$temp_string"`				
			do
				rot13=""
				firstbit=${eachline%% \(*}
				firstbit=${firstbit##*\}}
				firstbit=`echo $firstbit | xxd -u -ps` 	# | tr -d " "`
				firstbit=`echo $firstbit | tr -d " "`
				len_firstbit=$((${#firstbit}/2))
				x=0
				while [ $x -lt $len_firstbit ]		# do ROT-13
				do
					char=${firstbit:($x*2):2}
					case $char in
					41|42|43|44|45|46|47|48|49|4A|4B|4C|4D) dechar=`printf "%X" $((0x$char+0xD))`;;
					4E|4F|50|51|52|53|54|55|56|57|58|59|5A) dechar=`printf "%X" $((0x$char-0xD))`;;
					61|62|63|64|65|66|67|68|69|6A|6B|6C|6D) dechar=`printf "%X" $((0x$char+0xD))`;;
					6E|6F|70|71|72|73|74|75|76|77|78|79|7A) dechar=`printf "%X" $((0x$char-0xD))`;; 
					*) dechar=$char;;
					esac 
					rot13=$rot13$dechar
					(( x++ ))
				done
				firstbit=`echo $rot13 | xxd -r -p`	
				lastbit=`echo ${eachline##* = } | tr -d " "`
				uacount=${lastbit:14:2}${lastbit:12:2}${lastbit:10:2}${lastbit:8:2}
				uacount2=${lastbit:22:2}${lastbit:20:2}${lastbit:18:2}${lastbit:16:2}
				uatime=${lastbit:134:2}${lastbit:132:2}${lastbit:130:2}${lastbit:128:2}${lastbit:126:2}${lastbit:124:2}${lastbit:122:2}${lastbit:120:2}	# uatime = timestamp of last usage
				input_string=$uacount	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount=$output_string	# win 7 uacount seems to be # uses in current month not total
				uacount=`echo "ibase=16;obase=A;$uacount" | bc`
				input_string=$uacount2	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount2=$output_string
				uacount2=`echo "ibase=16;obase=A;$uacount2" | bc`
				if [ "$uatime" = "0000000000000000" ]
				then
					uatime=""
				else
					uatime=`echo $((0x$uatime/10000000-11644473600))`  #convert windowstime to unix time
					uatime=`date -d @$uatime 2>/dev/null`		   #convert unixtime 
				fi
				uassist_desktop[$z]=${uassist_desktop[$z]}"$lfcr"" "$firstbit" ("$uacount") "" ("$uacount2") "$uatime
			done
			IFS=$p
		fi
	done
################################ the xp/vista bit ##########################################################################
else		
	z=0
	while [ $z -lt $num_ntuser_hives ]
	do
		(( z++ ))
		temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{5E6AB780-7743-11CF-A12B-00AA004AE837}\Count" -v 2>/dev/null`
		if [ "$logging" != "off" ]						
		then
			echo "$temp_string" >> $expert_log_location			
		fi
		if [ -z "$temp_string" ]
		then
			uassist_intexp[$z]="There are no entries associated with this user"
		else
			uassist_intexp[$z]=${temp_string%%]*} 
 			uassist_intexp[$z]=`echo ${uassist_intexp[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
			temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
			p=$IFS
			IFS=$'\n'
			for eachline in `echo "$temp_string"`				
			do
				rot13=""
				firstbit=${eachline%% \(*}
				firstbit=${firstbit##*\}}
				firstbit=`echo $firstbit | xxd -u -ps` 	# | tr -d " "`
				firstbit=`echo $firstbit | tr -d " "`
				len_firstbit=$((${#firstbit}/2))
				x=0
				while [ $x -lt $len_firstbit ]		# do ROT-13
				do
					char=${firstbit:($x*2):2}
					case $char in
					41|42|43|44|45|46|47|48|49|4A|4B|4C|4D) dechar=`printf "%X" $((0x$char+0xD))`;;
					4E|4F|50|51|52|53|54|55|56|57|58|59|5A) dechar=`printf "%X" $((0x$char-0xD))`;;
					61|62|63|64|65|66|67|68|69|6A|6B|6C|6D) dechar=`printf "%X" $((0x$char+0xD))`;;
					6E|6F|70|71|72|73|74|75|76|77|78|79|7A) dechar=`printf "%X" $((0x$char-0xD))`;; 
					*) dechar=$char;;
					esac 
					rot13=$rot13$dechar
					(( x++ ))
				done
				firstbit=`echo $rot13 | xxd -r -p`	
				lastbit=`echo ${eachline##* = } | tr -d " "`
				uacount=${lastbit:14:2}${lastbit:12:2}${lastbit:10:2}${lastbit:8:2}
				uatime=${lastbit:30:2}${lastbit:28:2}${lastbit:26:2}${lastbit:24:2}${lastbit:22:2}${lastbit:20:2}${lastbit:18:2}${lastbit:16:2}		# uatime = timestamp of last usage
				input_string=$uacount	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount=$output_string		
				uacount=`echo "ibase=16;obase=A;$uacount" | bc` # counting starts @ 6
				if [ "$uacount" -lt "6" ] && [ "${firstbit:0:12}" = "UEME_RUNPIDL" ]
				then				# if the count is < 6 for pidl then not a run eg mouseover
					uacount="0"		# if it's greater than 6 and pidl same rules as for path
				else 				# and cpl, -5 to get actual run count
					if [ "${firstbit:0:12}" = "UEME_RUNPATH" ] || [ "${firstbit:0:11}" = "UEME_RUNCPL" ] || [ "${firstbit:0:12}" = "UEME_RUNPIDL" ]
					then
						uacount=$(($uacount-5))
					fi
				fi	
				if [ "$uatime" = "0000000000000000" ]
				then
					uatime=""
				else
					uatime=`echo $((0x$uatime/10000000-11644473600))`  #convert windowstime to unix time
					uatime=`date -d @$uatime 2>/dev/null`		   #convert unixtime 
				fi
				uassist_intexp[$z]=${uassist_intexp[$z]}"$lfcr"" "$firstbit" ("$uacount") "$uatime
			done
			IFS=$p
		fi
		temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{75048700-EF1F-11D0-9888-006097DEACF9}\Count" -v 2>/dev/null`
		if [ "$logging" != "off" ]						
		then
			echo "$temp_string" >> $expert_log_location			
		fi
		if [ -z "$temp_string" ]
		then
			uassist_desktop[$z]="There are no entries associated with this user"
		else
			uassist_desktop[$z]=${temp_string%%]*} 
 			uassist_desktop[$z]=`echo ${uassist_desktop[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
			temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
			p=$IFS
			IFS=$'\n'
			for eachline in `echo "$temp_string"`				
			do
				rot13=""
				firstbit=${eachline%% \(*}
				firstbit=${firstbit##*\}}
				firstbit=`echo $firstbit | xxd -u -ps` 	# | tr -d " "`
				firstbit=`echo $firstbit | tr -d " "`
				len_firstbit=$((${#firstbit}/2))
				x=0
				while [ $x -lt $len_firstbit ]		# do ROT-13
				do
					char=${firstbit:($x*2):2}
					case $char in
					41|42|43|44|45|46|47|48|49|4A|4B|4C|4D) dechar=`printf "%X" $((0x$char+0xD))`;;
					4E|4F|50|51|52|53|54|55|56|57|58|59|5A) dechar=`printf "%X" $((0x$char-0xD))`;;
					61|62|63|64|65|66|67|68|69|6A|6B|6C|6D) dechar=`printf "%X" $((0x$char+0xD))`;;
					6E|6F|70|71|72|73|74|75|76|77|78|79|7A) dechar=`printf "%X" $((0x$char-0xD))`;; 
					*) dechar=$char;;
					esac 
					rot13=$rot13$dechar
					(( x++ ))
				done
				firstbit=`echo $rot13 | xxd -r -p`	
				lastbit=`echo ${eachline##* = } | tr -d " "`
				uacount=${lastbit:14:2}${lastbit:12:2}${lastbit:10:2}${lastbit:8:2}
				uatime=${lastbit:30:2}${lastbit:28:2}${lastbit:26:2}${lastbit:24:2}${lastbit:22:2}${lastbit:20:2}${lastbit:18:2}${lastbit:16:2}		# uatime = timestamp of last usage
				input_string=$uacount	# chop off the leading zeros
				input_string_length=8
				leading_zeros_func
				uacount=$output_string		
				uacount=`echo "ibase=16;obase=A;$uacount" | bc`	# counting starts @ 6
				if [ $uacount -lt "6" ] && [ ${firstbit:0:12} = "UEME_RUNPIDL" ]
				then				# if the count is < 6 for pidl then not a run eg mouseover
					uacount="0"		# if it's greater than 6 and pidl same rules as for path
				else 				# and cpl, -5 to get actual run count
					if [ "${firstbit:0:12}" = "UEME_RUNPATH" ] || [ "${firstbit:0:11}" = "UEME_RUNCPL" ] || [ "${firstbit:0:12}" = "UEME_RUNPIDL" ]
					then
						uacount=$(($uacount-5))
					fi
				fi					
				if [ "$uatime" = "0000000000000000" ]
				then
					uatime=""
				else
					uatime=`echo $((0x$uatime/10000000-11644473600))`  #convert windowstime to unix time
					uatime=`date -d @$uatime 2>/dev/null`		   #convert unixtime 
				fi
				uassist_desktop[$z]=${uassist_desktop[$z]}"$lfcr"" "$firstbit" ("$uacount") "$uatime
			done
			IFS=$p
		fi
	done
fi
}

######################################################################
# Get run MRUlist						     #
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU     #
# Assigns: runmru[$z] for each user hive			     #
######################################################################

get_ntuser_runmru_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		runmru[$z]="There are no entries associated with this user"
	else
		runmru[$z]=${temp_string%%]*} 
 		runmru[$z]=`echo ${runmru[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		temp_string=${temp_string#*]}	# take the timestamp etc out of temp_string
		i=0		
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			(( i++ ))
			firstbit[$i]=${eachline%% \(*}	# the a,b,c etc or MRUlist
			cmdbit[$i]=${eachline##* = }	# just the command
			if [ "${firstbit[$i]}" = "MRUList" ]
			then 
				mruorder=${cmdbit[$i]}
				(( i-- ))		# don't increment i if its the mrulist rather than an entry
			else
				cmdbit[$i]=${cmdbit[$i]%%??}		# all bar the last two chars typically \1
			fi			
		done
		((num_runmru=i))
		IFS=$p
		i=0	# the pointer for each element in mruorder
		while [ $i -lt $num_runmru ]
		do
			x=0 # the pointer for each firstbit[$?]
			(( i++ ))
			while [ $x -lt $num_runmru ]
			do
				(( x++ ))
				if [ "${mruorder:($i-1):1}" = "${firstbit[$x]}" ]
				then
					runmru[$z]=${runmru[$z]}$crlf" "${cmdbit[$x]}
					x=$num_runmru	# if you find a match stop looking
				fi
			done
		done

	fi
done
}

######################################################################
# Get run OpenSaveMRU						     #
# gets strings for opensavemru[$z] for each user hive		     #
######################################################################

get_ntuser_opensavemru_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	if [ "$wpd" = "yes" ]
	then
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU" -v 2>/dev/null`
	else
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU" -v 2>/dev/null`
	fi
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		opensavemru[$z]="There are no entries associated with this user"
		opensave_num_exts[$z]=0
	else
	i=0
	opensave_date[$z]=${temp_string%%]*}	
	opensave_date[$z]=`echo ${opensave_date[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)"
	opensave_ext[$z$i]=${temp_string%%]*}	# $z$i = $z0 to root mru
#################### extract MRU for each extention #######################	
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds an extention subkey
		then
			(( i++ ))
			opensave_ext[$z$i]=${eachline##*..?}
			opensave_name[$z$i]=${opensave_ext[$z$i]}
			if [ "$wpd" = "yes" ]
			then
				opensave_ext[$z$i]=`perl $regdump_location ${ntu_loc[$z]} "Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU$bslash${opensave_ext[$z$i]}" -v`
			else
				opensave_ext[$z$i]=`perl $regdump_location ${ntu_loc[$z]} "Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU$bslash${opensave_ext[$z$i]}" -v`
			fi
			if [ "$logging" != "off" ]		 					
		  	then
				echo "${opensave_ext[$z$i]}" >> $expert_log_location
		  	fi
		fi
	done
	IFS=$p
	((opensave_num_exts[$z]=i))
	fi
done
}

######################################################################
# Sort OpenSaveMRU						     #
# Assigns : osmru_list[$z] for each user hive			     #
######################################################################

sort_ntuser_opensavemru_func () {

if [ "$wpd" = "yes" ]
then
	# the vista+ bit
	z=0		# the pointer for each user hive
	while [ $z -lt $num_ntuser_hives ]
	do
		(( z++ ))
		mrustring=""
		i=1	# the pointer for each extention
		while [ $i -le ${opensave_num_exts[$z]} ]
		do
			exist=`echo "${opensave_ext[$z$i]}" | grep -c "MRUListEx"`
			if [ $exist -gt "0" ]	# if there is an MRUList
			then
				osmrulist_date[$z$i]=${opensave_ext[$z$i]%%]*}  
				osmrulist_date[$z$i]=`echo ${osmrulist_date[$z$i]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
				osmrulist[$z$i]=`echo ${opensave_ext[$z$i]}|awk -F'MRUListEx \(REG_BINARY\) = |ff ff ff ff' '{print $2}'`
				mrustring=$mrustring$lfcr${opensave_name[$z$i]}" Most Recently Used List - "${osmrulist_date[$z$i]}$lfcr
				### generate array of entries for current extention ###
				q=0
				p=$IFS
				IFS=$'\n'
				for eachline in `echo "${opensave_ext[$z$i]}"`
				do
					(( q++ ))
					os_entry_num[$q]=${eachline%%?(*}
					os_ext_entry[$q]=`echo ${eachline##*=} | tr -d " "` 
					pos_ext_entry[$q]=${os_ext_entry[$q]%00[1-9a-fA-F][0-9a-fA-F]00[1-9a-fA-F][0-9a-fA-F]000000[1-9][0-9a-fA-F]000000*}
					pos_ext_entry[$q]=${pos_ext_entry[$q]##*000000}
					endbit=${os_ext_entry[$q]##*${pos_ext_entry[$q]}}
					endbit=${endbit:0:8}
					os_ext_entry[$q]=${pos_ext_entry[$q]}$endbit
					os_ext_entry[$q]=`echo ${os_ext_entry[$q]} | xxd -r -p`
				done
				IFS=$p
				num_ext_entries=$q
				### end of array generation ###
				y=0	# counter for number of mru entries
				x=0	# marker for position to extract little endian data nb 1 space between data
				finish="no"
				while [ $finish = "no" ]
				do
					mru_num[$y]=${osmrulist[$z$i]:($x+9):2}${osmrulist[$z$i]:($x+6):2}${osmrulist[$z$i]:($x+3):2}${osmrulist[$z$i]:$x:2}
					x=$x+12 # move to the next entry
					if [ -z "${mru_num[$y]}" ]	# if the last mru entry didn't exist
					then
						no_entries[$z$i]=$y
						finish="yes"
					else
						mru_num[$y]=`echo ${mru_num[$y]}| tr '[:lower:]' '[:upper:]'`
						mru_num[$y]=`echo "ibase=16;obase=A;${mru_num[$y]}" | bc` # convert to decimal
						q=0
						while [ $q -lt $num_ext_entries ]
						do
							(( q++ ))
							if [ "${os_entry_num[$q]}" = "${mru_num[$y]}" ]
							then
								mrustring=$mrustring" "${os_ext_entry[$q]}$lfcr	
								q=$num_ext_entries
							fi
						done
						(( y++ ))
					fi
				done
			fi
			(( i++))
		done
		osmru_list[$z]=$mrustring
	done

else	# the xp bit
	z=0	# pointer for user hives
	while [ $z -lt $num_ntuser_hives ]
	do
		(( z++ ))
		mrustring=""
		i=0
		while [ $i -lt ${opensave_num_exts[$z]} ]
		do
			(( i++ ))	# pointer for each opensave mru list within a hive
			exist=`echo "${opensave_ext[$z$i]}" | grep -c "MRUList"`
			if [ $exist -gt "0" ]	# if there is an MRUList
			then
				osmrulist_date[$z$i]=${opensave_ext[$z$i]%%]*}  
				osmrulist_date[$z$i]=`echo ${osmrulist_date[$z$i]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
				osmrulist=`echo "${opensave_ext[$z$i]##*MRUList (REG_SZ) = }"`
				osmrulist=`echo ${osmrulist%%$linefeed*}`
				osmrulist_len=${#osmrulist}
				mrustring=$mrustring$lfcr${opensave_name[$z$i]}" OPEN/SAVE Most Recently Used List - "${osmrulist_date[$z$i]}$lfcr	
				x=0	# used as pointer to mru entries within a list 
				while [ $x -lt $osmrulist_len ]
				do
					(( x++ ))
					next_entry=`echo "${opensave_ext[$z$i]##*${osmrulist:($x-1):1} (REG_SZ) = }"`
					next_entry=`echo ${next_entry%%$linefeed*}`
					mrustring=$mrustring"  "$next_entry$lfcr
				done
			else
				osmrulist_date[$z$i]=${opensave_ext[$z$i]%%]*}  
				osmrulist_date[$z$i]=`echo ${osmrulist_date[$z$i]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
				mrustring=$mrustring$lfcr${opensave_name[$z$i]}" OPEN/SAVE Most Recently Used List - "${osmrulist_date[$z$i]}$lfcr"  No Entries!"$lfcr
			fi
		done
		osmru_list[$z]=$mrustring
	done
fi
}

#########################################################
# Pull out userspecific autoruns from the user hive   	#
# HKCU\System\Microsoft\Windows\CurrentVersion\Run	#
# Assigns:	$user_autorun[$z]			#
#########################################################

get_ntuser_autorun_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Run" -v 2>/dev/null`
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
			user_autorun[$z]=${user_autorun[$z]}$IFS${eachline##* =}
		fi
	done
	IFS=$p
done
}

##############################################################
# Get terminal services mrulist				     #
# HKCU\Software\Microsoft\Terminal Server Client\Servers     #
# HKCU\Software\Microsoft\Terminal Server Client\Default     #
# Assigns: 	tsc[$z] 				     #
##############################################################

get_terminal_services_client_mru_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Terminal Server Client\Servers" -v 2>/dev/null`
	temp_string2=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Terminal Server Client\Default" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string""$temp_string2" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		tsc[$z]="  There are no Terminal Server entries associated with this user"
	else
		tscdefault=`echo "${temp_string2##*MRU0 (REG_SZ) = }"`
		tscdefault=`echo ${tscdefault%%$linefeed*}`
		tscdefault_upper=`echo $tscdefault | tr '[:lower:]' '[:upper:]'` # tscname often in upper
		tscdefault_date=${temp_string2%%]*} 
 		tscdefault_date=`echo ${tscdefault_date##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
			then
				tscname=${eachline##*..?}
				tsc_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Terminal Server Client\Servers$bslash$tscname" -v`
		  		if [ "$logging" != "off" ]						
		  		then
				echo "$tsc_string" >> $expert_log_location
		  		fi
				tsc_date=${tsc_string%%]*} 
 				tsc_date=`echo ${tsc_date##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
				tsc_uname=`echo "${tsc_string##*UsernameHint (REG_SZ) }"`
				tsc_uname=`echo ${tsc_uname%%$linefeed*}`
				if [ "$tscname" = "$tscdefault" ] || [ "$tscname" = "$tscdefault_upper" ]
				# if this name was the last used note it and add the timestamp case maybe an issue
				then
					tsc_date=$tsc_date")"$lfcr"   (Default since "$tscdefault_date
				fi
				tsc[$z]=${tsc[$z]}"  "$tscname" "$tsc_uname" ("$tsc_date")"$lfcr
			fi
		done
		IFS=$p
	fi
done
}

#################################################################################
# Get Computer Descriptions as seen by the network browser	     		#
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComputerDescriptions  #
# Assigns: 	$network_browser[$z] 				     		#
#################################################################################

get_network__browser_list_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\ComputerDescriptions" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		network_browser[$z]="There are no entries associated with this user"
	else
		network_browser[$z]=${temp_string%%]*} 
 		network_browser[$z]=`echo ${network_browser[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		temp_string="${temp_string#*]}"	# take the timestamp etc out of temp_string
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			firstbit=${eachline%%\(*}
			lastbit="("${eachline##* = }")"
			if [ "$lastbit" = "((no data))" ]
			then
				lastbit=""
			fi
			network_browser[$z]=${network_browser[$z]}$lfcr"  "$firstbit" "$lastbit
		done
		IFS=$p
	fi
done
}

#################################################################################
# Get mapped network drive mru if it exists			     		#
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU #
# Assigns: 	$networkdrive_mru[$z] 				     		#
#################################################################################

get_networkdrive_mru_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	if [ -z "$temp_string" ]
	then
		networkdrive_mru[$z]="There are no entries associated with this user"
	else
		networkdrive_mru[$z]=${temp_string%%]*} 
 		networkdrive_mru[$z]=`echo ${networkdrive_mru[$z]##*[} | tr "T" " " | tr "Z" " "`"(UTC)" 
		temp_string="${temp_string#*]}"	# take the timestamp etc out of temp_string
		mrulist=`echo "${temp_string##*MRUList (REG_SZ) = }"`
		mrulist=`echo ${mrulist%%$linefeed*}`
		num_entries=${#mrulist}
		y=0
		while [ $y -lt $num_entries ]
		do
			entry=`echo "${temp_string##*${mrulist:$y:1} (REG_SZ) = }"`
			entry=`echo ${entry%%$linefeed*}`
			networkdrive_mru[$z]=${networkdrive_mru[$z]}$lfcr"  "$entry
			(( y++ ))
		done 		
	fi
done
}

##################################################
# Get all the printer assignations by user(may   #
# contain server names)				 #
# HKCU\Printers\Connections			 #
# HKCU\Printers\DevModes2			 #
# Assigns: 	$printers[$z]			 #
##################################################

get_user_printers_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Printers\Connections" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	echo $temp_string | grep -q "\.\." 	# check if there are any subkeys
	if [ $? != "0" ]						
	then
		temp_string=""			# if there are no subkeys blank temp_string
	fi
	if [ -z "$temp_string" ] 	 	# if this is empty 
	then
		printers[$z]="  There are no printers listed in HKCU\Printers\Connections"
	else
	y=0
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`				
	do
		if [ "${eachline:0:2}" = ".." ]	# if the line holds a printer
		then
			(( y++ ))
			printername[$y]=${eachline##*..?}
			printers[$z]=${printers[$z]}"  "${printername[$y]}$lfcr
		fi
	done
	IFS=$p
	fi
	#### DevModes2bit ####
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Printers\DevModes2" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	echo $temp_string | grep -q "(REG_BINARY)" 	# check if there are no values
	if [ $? != "0" ]						
	then
		temp_string=""				# if there are no values blank temp_string
	fi
	if [ -z "$temp_string" ] 	 		# if this is empty 
	then
		printers[$z]=${printers[$z]}$lfcr"  There are no printers listed in HKCU\Printers\DevModes2"
	else
		p=$IFS
		IFS=$'\n'
		for eachline in `echo "$temp_string"`				
		do
			printername=${eachline##*]}
			printername=${printername%%\(*}
			printers[$z]=${printers[$z]}"  "$printername$lfcr
		done
		IFS=$p
	
	fi
done
}

###########################################################
# Get out user specific network drives from the user hive #
# HKCU\Network						  #
# Assigns:	$user_network[$z]			  #
###########################################################

get_network_drives_func () {
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	temp_string=`perl $regdump_location "${ntu_loc[$z]}" "Network" -v 2>/dev/null`
	if [ "$logging" != "off" ]						
	then
		echo "$temp_string" >> $expert_log_location			
	fi
	y=0
	p=$IFS
	IFS=$'\n'
	for eachline in `echo "$temp_string"`
	do
		if [ "${eachline:0:2}" = ".." ]				# if the line holds a username
		then
			(( y++ ))
			netdrive_letter[$y]=${eachline##*..?}
			netdrive[$y]=`perl $regdump_location "${ntu_loc[$z]}" "Network$bslash${netdrive_letter[$y]}" -v`
		  	if [ "$logging" != "off" ]						
		  	then
				echo "${netdrive[$y]}" >> $expert_log_location
		  	fi
			remote_path=`echo "${netdrive[$y]##*RemotePath (REG_SZ) = }"`
			remote_path=`echo ${remote_path%%$linefeed*}`
			net_username=`echo "${netdrive[$y]##*UserName (REG_SZ) = }"`
			net_username=`echo ${net_username%%$linefeed*}`
			user_network[$z]=${user_network[$z]}"  "${netdrive_letter[$y]}": = "$remote_path" - Username = "$net_username$lfcr
		fi
	done
	IFS=$p
	if [ -z "${user_network[$z]}" ]
	then
		user_network[$z]="  There are no entries associated with this user"$lfcr
	fi
done
}

#############################################
# cut leading zeros call by setting 	    #
# input_string & input_string_length	    #
# returns output_string			    #
#############################################

leading_zeros_func () {
v=0
while [ "${input_string:$v:1}" = "0" ]
do
	(( v++ ))
done
if [ $v -lt $input_string_length ]
then
	output_string=`echo ${input_string:$v:($input_string_length-$v)} | tr '[:lower:]' '[:upper:]'` # added tr for RD_MRUS
else
	output_string=0
fi
}

#############################################
#         Output info to screen    	    #
#############################################

output_to_screen_func () {
if [ "$logging" = "off" ]						
then
	log_location="/dev/null"
fi
i=0
echo "There are "$num_users" users associated with this system ("$comp_name")" | tee $log_location
echo | tee -a $log_location
until [ $i -eq $num_users ]
do
	(( i++ ))

	echo "Username : "${name[$i]} | tee -a $log_location		# output to screen and file
	echo "   RID                  : "${name_rid[$i]}" ("${rid[$i]}")" | tee -a $log_location	# -a is to append
	echo "   Last logon           : "${last_logon[$i]} | tee -a $log_location
	if [ -n "${user_profile_folder[$i]}" ]
	then
		echo "   Users Profile Folder : "${user_profile_folder[$i]} | tee -a $log_location
		echo "   Users NTUSER.DAT     : "${user_ntuser_loc[$i]} | tee -a $log_location
	fi
	
	echo "   Last password change : "${password_change[$i]} | tee -a $log_location
	echo "   Account expires      : "${account_expires[$i]} | tee -a $log_location
	echo "   Account enabled      : "${ac_enabled[$i]} | tee -a $log_location
	echo "   Last failed logon    : "${failed_logon[$i]} | tee -a $log_location
	echo "   Number of logons     : "${num_logons[$i]} | tee -a $log_location
	echo -e "   Member of group(s)   "${memberof[$i]} | tee -a $log_location
	echo | tee -a $log_location
done

i=0
echo | tee -a $log_location
echo "There are "$num_groups" groups associated with this system ("$comp_name")" | tee -a $log_location
echo | tee -a $log_location
until [ $i -eq $num_groups ]
do
	(( i++ ))

	echo "Groupname : "${groupname[$i]} | tee -a $log_location		# output to screen and file
	echo "   RID                  : "${group_rid[$i]} | tee -a $log_location	# -a is to append
	input_string=${num_members[$i]};input_string_length=8;leading_zeros_func
	echo "   Number of members    : "$output_string | tee -a $log_location
	if [ ${num_members[$i]} -gt "0" ]
	then
		y=0
		while [ $y -lt ${num_members[$i]} ]
		do
			(( y++ ))
			if [ "$y" = "1" ]
			then
				if [ ${groupname[$i]} = "Users"  ]
				then
					y=$((y+2))
				fi
				if [ $y -le ${num_members[$i]} ] # in users don't print a blank 3rd group
				then
					echo "   Group members        : "${group_members_name[$i$y]}" ("${group_members_rid[$i$y]}")" | tee -a $log_location
				fi
			else
				echo "                          "${group_members_name[$i$y]}" ("${group_members_rid[$i$y]}")" | tee -a $log_location
			fi
		done
	fi
	echo | tee -a $log_location
done

#################################################################################
z=0
while [ $z -lt $num_ntuser_hives ]
do
	(( z++ ))
	echo | tee -a $log_location
	echo "Username = "${ntu_name[$z]} | tee -a $log_location
	echo "Hive = "${ntu_loc[$z]} | tee -a $log_location
	echo | tee -a $log_location
	echo "User Profile subfolders:" | tee -a $log_location
	echo "%USERPROFILE% = "${ntu_profile_folder[$z]}"${ntu_user_shell_folders[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "RECENTDOCS: "${rdocs_date[$z]} | tee -a $log_location
	echo -e ${mru_list[$z]} | tee -a $log_location
	echo -e "MEDIAPLAYER MRU - ""${mediaplayer[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo -e "TYPED URLs - ""${urllist[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo -e "RUN MRU LIST - ""${runmru[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "USERASSIST EXPLORER -""${uassist_intexp[$z]}" | tee -a $log_location
	echo | tee -a $log_location
 	echo "USERASSIST DESKTOP - ""${uassist_desktop[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "USER SPECIFIC AUTORUNS - ""${user_autorun[$z]}" | tee -a $log_location 
	echo | tee -a $log_location
	echo "REMOTE DESKTOP TERMINAL SERVERS " | tee -a $log_location
	echo "${tsc[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "SYSTEMS SEEN BY NETWORK BROWSER - ""${network_browser[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "RECENTLY MAPPED NETWORK DRIVES - ""${networkdrive_mru[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "RECONNECT AT LOGIN NETWORK DRIVES" | tee -a $log_location
	echo "${user_network[$z]}" | tee -a $log_location
	echo "PRINTERS" | tee -a $log_location
	echo "${printers[$z]}" | tee -a $log_location
	echo | tee -a $log_location
	echo "OPEN/SAVE MRUs" | tee -a $log_location
	echo "${osmru_list[$z]}" | tee -a $log_location
	
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
	sam_location=$default_location"/sam"
	if [ ! -f "$sam_location" ]					# look for sam or SAM ?
	then
		sam_location=$default_location"/SAM"
	fi
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

if [ ! -f "$sam_location" ]
	then
		clear
		echo "You must enter a valid SAM hive"
fi


#### if args are valid run functions ####
current_control_set_func
get_compname_func
get_winver_func
profile_list_func
get_usernames_func
get_timestamps_func
get_groupnames_func
get_members_func
get_ntuser_hives_func
get_ntuser_data_func
get_ntuser_mrulist_func
get_ntuser_mediaplayer_mru_func
get_ntuser_runmru_func
get_ntuser_typed_urls_func
get_userassist_func
get_ntuser_autorun_func
get_terminal_services_client_mru_func
get_network__browser_list_func
get_networkdrive_mru_func
get_user_printers_func
get_network_drives_func
get_ntuser_opensavemru_func
sort_ntuser_opensavemru_func
output_to_screen_func
exit


