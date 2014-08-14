#!/bin/bash 
###############################################
# Utility to collect and preserve registry    #
# files Jacky Fox 2012 			      #
###############################################

#############################################
# variable settings			    #
#############################################

log_location="extractreg.log"
fdiskop="fdiskoutput.fil"	 

##########################################
#   command line help function           #
##########################################

cmd_line_help_func() {

echo "usage : "$0" -o /mnt/usbntfs -i sda2 -t system -c coffee"
echo "	-o (output path for files collected)	  	-o /mnt/usbntfs"
echo "	-i (full path to image)				-i /mnt/ex_volume"
echo "	-t (type of volume enter system, image)		-t system"
echo "	-c (casename)					-c mycase"
exit
}


###################################################################
# Check that the specifed disk can be mounted 			  #
# exit on error ( e.g. -i set to sd2 -t set to system		  #
###################################################################

system_mount_volume_func () {
	
	sudo mkdir /mnt/ex_volume
	sudo fdisk -l > "$fdiskop"
	cat "$fdiskop"
	thedev=`cat $fdiskop | grep 'dev' | grep '*'`
	thedev="${thedev%% *}"
	#echo "here"$thedev
	echo
	read -p "Enter device to extract (press enter for $thedev) " -e answer
	if [ -z "$answer" ]
	then
		thedev="$thedev"
	else		
		thedev="$answer"
	fi
	echo 
	echo "Attempting to extract files from "$thedev
	echo
	sudo mount -o ro "$thedev" /mnt/ex_volume
	if [ $? != "0" ] 
	then 
		echo "Unable to mount specified volume check fdisk output and try again"
		exit
	fi	
	input="/mnt/ex_volume"
}


###################################################################
# Test for input file if extracting files from a mounted image	  #
# 								  #
###################################################################

check_bitimage_func () {

	if [ ! -d "$extraction_path" ] 	 					 
	then
		echo "Unable to locate specified mounted image check path"
		exit
	else
		input="$extraction_path"
	fi
}


#################################################################
# Extract the files						#
#################################################################

extract_reg_func () {

	# $dirname = path casename + current date and time on system in use (should be unique)
	thedate=`date | tr ":" "." | tr " " "."`	
	dirname="$output_volume/$casename$thedate"
	log="$dirname/log"
	zip="$dirname/zip"
	mkdir "$dirname"
	mkdir "$log"
	mkdir "$zip"
	if [ "$volume_type" = "system" ]
	then
 		cp "$fdiskop" "$log/$fdiskop"
	fi
	# list the registry files to the log file 
	# note linux case specific filesnames have been seen upper & lowercase - use of iname
	# setupapi.dev.log has been found with date and time included
	touch "$log/$log_location"
	#vista+
	sudo find "$input/Windows/System32/config" -maxdepth 1 -iname software >> "$log/$log_location" 2>/dev/null
	sudo find "$input/Windows/System32/config" -maxdepth 1 -iname system >> "$log/$log_location" 2>/dev/null
	sudo find "$input/Windows/System32/config" -maxdepth 1 -iname sam >> "$log/$log_location" 2>/dev/null
	sudo find "$input/Windows/System32/config" -maxdepth 1 -iname security >> "$log/$log_location" 2>/dev/null
	sudo find "$input/Windows/inf" -iname setupapi.dev.log >> "$log/$log_location" 2>/dev/null 
	sudo find "$input/Windows/inf" -iname setupapi.dev.????????_??????.log >> "$log/$log_location" 2>/dev/null 
	sudo find "$input/Users" -iname ntuser.dat >> "$log/$log_location" 2>/dev/null 
	#XP
	sudo find "$input/WINDOWS/system32/config" -maxdepth 1 -iname software >> "$log/$log_location" 2>/dev/null
	sudo find "$input/WINDOWS/system32/config" -maxdepth 1 -iname system >> "$log/$log_location" 2>/dev/null
	sudo find "$input/WINDOWS/system32/config" -maxdepth 1 -iname sam >> "$log/$log_location" 2>/dev/null
	sudo find "$input/WINDOWS/system32/config"   -maxdepth 1 -iname security >> "$log/$log_location" 2>/dev/null
	sudo find "$input/WINDOWS" -iname setupapi.log >> "$log/$log_location" 2>/dev/null 
	sudo find "$input/Documents and Settings" -iname ntuser.dat >> "$log/$log_location" 2>/dev/null 
	# the .lnk files
	sudo find "$input" -iname *.lnk >> "$log/$log_location" 2>/dev/null 	

	# zip the files and store in the zip directory with md5 checksum
	while IFS= read line
	do
		sudo md5sum "$line"
	done < "$log/$log_location" > "$log/md5eachfileprecopy.log"
	cat "$log/$log_location" | sudo zip "$zip/$casename.zip" -@
	md5sum "$zip/$casename.zip" > "$log/$casename.md5"
	if [ "$volume_type" = "system" ]
	then
		sudo umount "$input"
	fi
	echo "The following files have been extracted and stored in "$zip" :"
	cat "$log/$log_location"
	echo
	echo "md5 checksum : "
	cat "$log/$casename.md5"	
}



#############################################
#	Main process			    #
#############################################

# check if the args are valid
if [ "$1" = "-h" ]
then
	cmd_line_help_func
fi

while [ $# -gt 1 ]
	do
	case $1 in
	-t) volume_type=$2 ; shift 2 ;;
	-i) extraction_path=$2 ; shift 2 ;;
	-o) output_volume=$2 ; shift 2;;
	-c) casename=$2 ; shift 2;;
	*) shift 1;;
	esac 
done

# Check that the required switches are entered #


if [[ "$volume_type" = "image" || "$volume_type" = "system" ]] 
then
	answer="Later"
	# do nothing
else
	echo "You must enter a valid volume type: image or system"
	cmd_line_help_func
fi
if [[ -z "$extraction_path" && "$volume_type" != "system" ]]
then
	echo "You must enter the complete path to an image eg. /mnt/evidence/mycase.e01"
	cmd_line_help_func
fi
if [ -z "$output_volume" ]
then
	echo "You must enter a valid output path"
	cmd_line_help_func
fi
if [ -z "$casename" ]
then
	echo "You must enter a case name"
	cmd_line_help_func
fi


#### if args are valid run functions ####
if [ "$volume_type" = "system" ]
then
	system_mount_volume_func
elif [ "$volume_type" = "image" ]
then
	check_bitimage_func
else
	echo "You must enter a valid volume type"
	exit
fi
extract_reg_func
exit


