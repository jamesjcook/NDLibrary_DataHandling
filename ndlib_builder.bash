#!/bin/bash
#Libraary updater



# for a givne base folder,
# find all of its contents and update from server

source_dir=/Volumes/DataLibraries

base_path=$1;
echo Base path $base_path;
if [ ! -z "$2" ];
then
    echo Source_path $2
    source_dir=$2;
fi;
exit ;
#for file in `find $base_path -type f -exec echo \"{}\" \;`; # this is an attmpe to handle names with spaces, that was unsucessful
for file in `find $base_path -type f`;
do
    #sed —b -i -e "s/000Mammalian_Brain/000Mouse_Brain/g"
    if [[ $file != *"junk"* ]];
       then
           src_file=`echo $file |sed -e "s:$base_path:$source_dir:g"`
	   if [ "$file" -ot "$src_file" -o "x_$3"=="x_$1"] ; then
	       echo "#$file is older than $src_file" ;
	       echo "cp -p $src_file $file";
	       cp -fp $src_file $file
	   else
	       if [ -e "$src_file" ];
	       then
		   echo "  #no copy! $file";
	       else
		   echo "  #no file! $src_file";
		   echo "cp -p $file $src_file";
	       fi
		   
	   fi;
    else
	echo "    #junk! $file";
    fi;
done;
#echo "#diff -qrx \"*~\" $base_path $source_dir" #|grep -v \"~"
#diff -qrx "*~" $base_path $source_dir

