#!/bin/bash 
###############################################
# Utility to unzip registry files collected   #
# via extraxtreg.sh files Jacky Fox 2012 			      #
###############################################

#############################################
# variable settings			    #
#############################################

delim=" /"
linefeed=$'\n'
log_location="extractreg.log"	 

##########################################
#   command line help function           #
##########################################

cmd_line_help_func() {

echo "usage : "$0" -o raw -d ../mycaseSun.Jan.22.18.27.23.UTC.2012"
echo "	-o (output path for unzipped files)	  	-o ../raw"
echo "	-d (location of extractreg container)	 	-d ../mycaseSun.Jan.22.18.27.23.UTC.2012"
exit
}


########################################
# Check that the log files exist       #
########################################

check_log_file_func () {
	
if [ ! -f $reg_container"/log/extractreg.log" ]
then
	echo "Unable to find extractreg.log in "$reg_container"/log - check -d option - use -d . for current dir"
	cmd_line_help_func
fi
}


###########################
# unzip the files	  #
###########################

unzip_files_func () {

zipfile=`ls $reg_container"/zip"`
echo "Current calculated md5 checksum"
echo $reg_container"/zip/"$zipfile
echo
md5sum $reg_container"/zip/"$zipfile
echo
if [ -d $reg_container"/log" ]
then
	echo "Recorded md5 checksum"
	cat $reg_container"/log/${zipfile%%.*}.md5"
	echo
fi
if [ -d $output_dir ]
then
	echo "dir already exists"
else
	mkdir $output_dir
fi
# get the S* registry files first
unzip -j -C $reg_container"/zip/"$zipfile *YSTEM -d $output_dir # unzip all *YSTEM files regardless of path & case
unzip -j -C $reg_container"/zip/"$zipfile *OFTWARE -d $output_dir
unzip -j -C $reg_container"/zip/"$zipfile *AM -d $output_dir
unzip -j -C $reg_container"/zip/"$zipfile *ECURITY -d $output_dir
if [ -f $output_dir"/software" ]				# make any lowercase files uppercase
then
	mv $output_dir"/software" $output_dir"/SOFTWARE"
fi
if [ -f $output_dir"/system" ]				
then	
	mv $output_dir"/system" $output_dir"/SYSTEM"
fi
if [ -f $output_dir"/sam" ]
then				
	mv $output_dir"/sam" $output_dir"/SAM"
fi
if [ -f $output_dir"/security" ]
then				
	mv $output_dir"/security" $output_dir"/SECURITY"
fi
# get setupapis
unzip -j -C $reg_container"/zip/"$zipfile *etupapi.log -d $output_dir # xp setupapi
unzip -j -C $reg_container"/zip/"$zipfile *etupapi.dev.log -d $output_dir # vista+ setupapi
unzip -j -C $reg_container"/zip/"$zipfile *etupapi.dev.????????.??????.log -d $output_dir # dated vista+ setupapi
# get the NTUSER.DATs
log=`cat $reg_container"/log/extractreg.log"`
#echo "log"$log
#striplog=$log
striplog=${log%%.lnk*} # don't process all the .lnk lines at this point
#echo "striplog"$striplog
i=0
j=0
while [ "$striplog" != "${zippath[$i]}" ]
do
	(( i++ ))
	zippath[$i]="${striplog%%$linefeed*}"
	userhive=${zippath[$i]##*"/"}
	#echo "hive "$userhive
	if [ "$userhive" = "NTUSER.DAT" ] || [ "$userhive" = "ntuser.dat" ]
	then
		(( j++ ))
		hivetotal=${zippath[$i]}
		hivefile=$userhive
		hivepath=${hivetotal%"/"*}
		username=${hivepath##*"/"}
		newhivename="NTUSER.DAT.""${username}"
		unzip -j -C $reg_container"/zip/"$zipfile "*${username}""/NTUSER.DAT" -d $output_dir 
		if [ -f $output_dir"/ntuser.dat" ]				
		then	
			mv $output_dir"/ntuser.dat" $output_dir"/""${newhivename}"
		else
			mv $output_dir"/NTUSER.DAT" $output_dir"/""${newhivename}"
		fi
	fi
	striplog=`echo "${striplog##*${zippath[$i]}$linefeed}"`
done
# get lnk files
if [ -d $output_dir/lnk ]
then
	echo "dir already exists"
else
	mkdir $output_dir/lnk # put the lnk files is a seperate dir
fi
unzip -jCB $reg_container"/zip/"$zipfile *lnk -d $output_dir/lnk # -B means if dupes ren to name~, name~1 etc

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
	-d) reg_container=$2 ; shift 2 ;;
	-o) output_dir=$2 ; shift 2;;
	*) shift 1;;
	esac 
done

# Check that the required switches are entered #


if [ -z $reg_container ] 
then
	echo "You must enter a valid path for the zip container"
	cmd_line_help_func
fi
if [ -z $output_dir ]
then
	echo "You must enter a valid output path for the unzipped files"
	cmd_line_help_func
fi


#### if args are valid run functions ####


check_log_file_func
unzip_files_func
exit


