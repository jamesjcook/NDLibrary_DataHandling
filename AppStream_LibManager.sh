#!/bin/bash
# script to setup our appstream libs

base_path=/Volumes/DataLibraries
dest_path=/Volumes/l\$/AppStreamLibraries

if [ ! -d $base_path -o ! -d $dest_path ]; then
    echo "Libraries not available!";
fi


do_rat=0;
do_mouse=1;
do_brainstem=0;
update_prod1_mouse=1;
choices="mouse rat human";
choice="mouse";

which realpath;rpf=$?;
if [ $rpf -eq 1 ] ; then
    echo "Setting up function realpath";
    #alias realpath="perl -MCwd -e 'print Cwd::realpath(\$ARGV[0]),qq<\n>'"
    function realpath () { perl -MCwd -e 'print Cwd::realpath($ARGV[0]),qq<\n>' $1; };
fi;

function index_update () {
    dirs=$1;
    match_pattern=$2;
    found_paths="";
    for dir in $dirs;
    do pc=`grep -ciE '^path' $dir/lib.conf 2> /dev/null|tail -n 1`;
       if [ ! -z "$match_pattern" -a -d $dir ]; then
	   if [ "x_`basename $dir |grep -cEv $match_pattern`" == "x_1" ];then
	       echo "  excluded $dir for not matching $match_pattern" >& 2;
  	       continue;
	   fi;
       fi;
       if [ "x_$pc" == "x_1" ];then
	   op=`grep -iE '^path' $dir/lib.conf|cut -d'=' -f2`;
	   op=`tr -dc '[[:print:]]' <<< "$op"`

	   #echo switch to $dir;
	   #echo switch to $op;
	   #echo "say pwd";
	   ap=`realpath $dir/$op`;
	   #ap=$(cd "$dir"; cd "$op"; pwd) 
	   echo "  $dir/lib.conf -> $ap/lib.conf" >& 2;
	   found_paths="$ap $found_paths";
	   #./LibManager.pl $base_path/000ExternalAtlasesBySpecies/mouse/example/lib.conf $base_path/ExternalAtlases/mitra/lib.conf
	   #sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/ExternalAtlases/mitra/lib.conf

	   echo ./LibManager.pl ${dir}/lib.conf $ap/lib.conf >& 2 >> cmd_list.txt;
	   ./LibManager.pl ${dir}/lib.conf $ap/lib.conf >& 2 ; # do the work
	   echo sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $ap/lib.conf >& 2 >> cmd_list.txt;
	   sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $ap/lib.conf >& 2; # do the work
       fi;
    done;
    echo $found_paths;
    return;
}

function main () {
if [ "x_$do_brainstem" == "x_1" ]; then
    echo DOING human brainstem
    # if[diff $base_path/040Human_Brainstem/040BrainStem/lib.conf $base_path/Brain/Human/130827-2-0/lib.conf]; then
    ./LibManager.pl $base_path/040Human_Brainstem/040BrainStem/lib.conf $base_path/Brain/Human/130827-2-0/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Human/130827-2-0/lib.conf
    # fi
    ./LibManager.pl $base_path/040Human_Brainstem/ $dest_path/DataLibraries_human_brainstem/040Human_Brainstem
    ./LibManager.pl $base_path/040Human_Brainstem/040BrainStem/ $dest_path/DataLibraries_human_brainstem/040Human_Brainstem
    ./LibManager.pl $base_path/Brain/Human/130827-2-0 $dest_path/DataLibraries_human_brainstem/Brain
fi

if [ "x_$do_rat" == "x_1" ]; then
    echo DOING rat;
    # Reduce Update....
    # first do an update of the source data from the source index. This should capture lib.conf(and probably only lib.conf) so they are consistent with one another.
    ./LibManager.pl $base_path/010Rat_Brain/21Rat/lib.conf $base_path/Brain/Rattus_norvegicus/Wistar/Xmas2015Rat/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Rattus_norvegicus/Wistar/Xmas2015Rat/lib.conf

    ./LibManager.pl $base_path/010Rat_Brain/23Rat/lib.conf $base_path/Brain/Rattus_norvegicus/Wistar/Developmental/00006912000/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Rattus_norvegicus/Wistar/Developmental/00006912000/lib.conf

    ./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Rat/example/lib.conf $base_path/ExternalAtlases/PaxinosWatson_265/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/ExternalAtlases/PaxinosWatson_265/lib.conf


    # now do an acutal index transfer
    ./LibManager.pl $base_path/010Rat_Brain $dest_path/DataLibraries_rat_brain/010Rat_Brain
    ./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Rat/example $dest_path/DataLibraries_rat_brain/000ExternalAtlasesBySpecies

    # real transfers
    ./LibManager.pl $base_path/ExternalAtlases/PaxinosWatson_265 $dest_path/DataLibraries_rat_brain/ExternalAtlases
    if [ 1 -eq 0 ] ; then
	echo -n ''
    fi
    ./LibManager.pl $base_path/Brain/Rattus_norvegicus/Wistar/Xmas2015Rat $dest_path/DataLibraries_rat_brain/Brain
    ./LibManager.pl $base_path/Brain/Rattus_norvegicus/Wistar/Developmental/00006912000 $dest_path/DataLibraries_rat_brain/Brain

    # not sure what i expect here, maybe i should specify each component? 
fi

if [ "x_$do_mouse" == "x_1" ]; then
    echo DOING $choice;
    # first do an update of the source data from the source index. This should capture lib.conf(and probably only lib.conf) so they are consistent with one another.
    #while doing these index updates, grab the real path to be updated as well.
    data_paths="";

    ###
    # Update source lib.conf from index
    ###
    choice_index=`ls -d $base_path/*|grep -i ${choice}`;# get datalibrary index dir
    echo "Updating indexes for $choice_index";
    dirs=`ls -d $choice_index/*|grep -i ${choice}|grep -vE '/9.*' `; # get index dirs inside that datalibrary index
    data_paths=`index_update "$dirs"`; # update the lib.conf in all data dirs based on the index file, comment out any path line in the data/lib.conf folder.
    # echo "should have done"; # these comments are to compare to old data.
    # echo "  $base_path/000Mouse_Brain/01Mouse/lib.conf $base_path/Brain/Mus_Musculus/mouse_chass_images/dti/lib.conf"
    # echo "  $base_path/000Mouse_Brain/03Mouse/lib.conf $base_path/Brain/Mus_Musculus/whs_atlas/dti101/lib.conf"
    # exit;

    ###
    # Update dest index 
    ### 
    bn=`basename $choice_index`; # get the folder name of the index.
    cn=$( echo "$bn" | tr '[:upper:]' '[:lower:]' | sed -E 's/^([0-9]*)//g' ) ; # make whole thing lower case, cut off any numbers, 
    choice_dest="DataLibraries_${cn}"; # make the destination name eg, 000Mouse_Brain becomes DataLibraries_mouse_brain
    dest_pile=${dest_path}"/${choice_dest}/${bn}"; # get the full dest name
    echo "Updating index";
    echo "  $choice_index -> $dest_pile"
    echo ./LibManager.pl $choice_index $dest_pile >> cmd_list.txt;
    ./LibManager.pl $choice_index $dest_pile; # do the work
    # echo "should have done"; # these comments are to compare to old data.
    # echo "  $base_path/000Mouse_Brain $dest_path/DataLibraries_mouse_brain/000Mouse_Brain";
    # exit;
    if [ 0 -eq 1 ] ; then # this is the old version of Update source lib.conf from index
	echo "OLD CODE BAD";
	exit;
	./LibManager.pl $base_path/000Mouse_Brain/01Mouse/lib.conf $base_path/Brain/Mus_Musculus/mouse_chass_images/dti/lib.conf
	sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Mus_Musculus/mouse_chass_images/dti/lib.conf
	exit;
	./LibManager.pl $base_path/000Mouse_Brain/03Mouse/lib.conf $base_path/Brain/Mus_Musculus/whs_atlas/dti101/lib.conf
	sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Mus_Musculus/whs_atlas/dti101/lib.conf
	exit;
    fi

    ###
    # Update external atlases of this choice
    ###
    choice_index=`ls -d $base_path/*ExternalAtlasesBySpecies/*|grep -i ${choice}`;#get datalibrary index dir
    echo "Updating indexes for $choice_index";
    dirs=`ls -d $choice_index/*|grep -i ${choice}|grep -vE '^9.*' `;# #get index dirs inside that datalibrary index
    data_paths="${data_paths} "`index_update "$dirs" "^example"`; #update the lib.conf in all data dirs based on the index file, ommitiing any which do not match pattern, commenting out any path lines in the data/lib.conf folder.
    # echo "should have done"; # these comments are to compare to old data.
    # echo "  $base_path/000ExternalAtlasesBySpecies/Mouse/example/lib.conf $base_path/ExternalAtlases/mitra/lib.conf"
    # echo "";
    # exit;
    data_paths="$choice_index/example $data_paths"; # add additional index it to the beginning of the data paths here, beacuse the whole index acts like the data path.
    echo "Found paths "; # show our data paths before we update those below.
    for p in $data_paths; do  echo "  "$p; done
    if [ 0 -eq 1 ] ; then
	echo "OLD CODE BAD";
	exit;
	./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Mouse/example/lib.conf $base_path/ExternalAtlases/mitra/lib.conf
	sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/ExternalAtlases/mitra/lib.conf
	exit;
    fi;
    
    if [ 0 -eq 1 ]; then
	exit;
	# now do an acutal index transfer
	./LibManager.pl $base_path/000Mouse_Brain $dest_path/DataLibraries_mouse_brain/000Mouse_Brain
	./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Mouse/example $dest_path/DataLibraries_mouse_brain/000ExternalAtlasesBySpecies
    fi;
    #size=${#myvar}
    #b=${a:12:5}
    ###
    # update the actual data.
    ##
    echo "Updating Data... ";
    for dir in $data_paths ; do
	length=`realpath $base_path`;length=${#length}; # get length of base_path
	out_suffix=${dir:(($length+1))}; # remove the base path, so we can add the dets path.
	echo "  $dir -> $dest_path/$choice_dest/$out_suffix"
	echo "./LibManager.pl $dir $dest_path/$choice_dest/$out_suffix"  >> cmd_list.txt; 
	./LibManager.pl $dir $dest_path/$choice_dest/$out_suffix; # do the work
    done;
    # echo "should have done"; # these comments are to compare to old data.
    # echo "  $base_path/000ExternalAtlasesBySpecies/Mouse/example $dest_path/DataLibraries_mouse_brain/000ExternalAtlasesBySpecies";
    # echo "  $base_path/ExternalAtlases/mitra $dest_path/DataLibraries_mouse_brain/ExternalAtlases";
    # echo "  $base_path/Brain/Mus_Musculus/mouse_chass_images/dti $dest_path/DataLibraries_mouse_brain/Brain";
    # echo "  $base_path/Brain/Mus_Musculus/whs_atlas/dti101 $dest_path/DataLibraries_mouse_brain/Brain";
    # echo "";
    # real transfers
    if [ 0 -eq 1 ] ; then 
	./LibManager.pl $base_path/ExternalAtlases/mitra $dest_path/DataLibraries_mouse_brain/ExternalAtlases
	if [ 1 -eq 0 ] ; then
	    echo -n ''
	fi
	./LibManager.pl $base_path/Brain/Mus_Musculus/mouse_chass_images/dti $dest_path/DataLibraries_mouse_brain/Brain
	./LibManager.pl $base_path/Brain/Mus_Musculus/whs_atlas/dti101 $dest_path/DataLibraries_mouse_brain/Brain

    fi;
fi


if [ "x_$update_prod1" == "x_1" ]; then
    echo "Updating production 1";

    # THIS IS MORE DANGEROUS
    # SO we'll just echo the parts out here.
    # 
    # 
    #dest_path=/Volumes/l\$/AppStreamLibraries
    # not sure what i expect here, maybe i should specify each component?
    base_path='/Volumes/DataLibraries';
    `mount|grep pwp-civm-ctx01.win |grep c\$`
    dest_c=`mount|grep pwp-civm-ctx01.win|grep '/c' |cut -d ' ' -f 3`;
    if [ -L /Volumes/DataLibraries/.AppStreamManagement/prod1DataLibraries ]; then 
	echo "Unlinking old."
	unlink "/Volumes/DataLibraries/.AppStreamManagement/prod1DataLibraries";
    fi

    if [  -z "$dest_c"  ]; then
	echo "Couldnt find proper drive.";
	exit;
    fi;
    exit;
    ln -fs $dest_c/DataLibraries "/Volumes/DataLibraries/.AppStreamManagement/prod1DataLibraries";
    dest_path='/Volumes/DataLibraries/.AppStreamManagement/prod1DataLibraries';

    ## this $ reaks. Causes much havok in the perl code. gotta get it out of there.
    #echo ./LibManager.pl -d 100 $base_path/Brain/Mus_Musculus/mouse_chass_images/dti $dest_path/Brain
    #echo ./LibManager.pl -d 100 $base_path/Brain/Mus_Musculus/whs_atlas/dti101 $dest_path/Brain
    #exit;
    # Reduce Update....
    # first do an update of the source data from the source index. This should capture lib.conf(and probably only lib.conf) so they are consistent with one another.
    ./LibManager.pl $base_path/000Mouse_Brain/01Mouse/lib.conf $base_path/Brain/Mus_Musculus/mouse_chass_images/dti/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Mus_Musculus/mouse_chass_images/dti/lib.conf

    ./LibManager.pl $base_path/000Mouse_Brain/03Mouse/lib.conf $base_path/Brain/Mus_Musculus/whs_atlas/dti101/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/Brain/Mus_Musculus/whs_atlas/dti101/lib.conf

    ./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Mouse/example/lib.conf $base_path/ExternalAtlases/mitra/lib.conf
    sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" $base_path/ExternalAtlases/mitra/lib.conf


    # now do an acutal index transfer 
    ./LibManager.pl $base_path/000Mouse_Brain $dest_path/000Mouse_Brain
    ./LibManager.pl $base_path/000ExternalAtlasesBySpecies/Mouse/example $dest_path/000ExternalAtlasesBySpecies

    # real transfers
    ./LibManager.pl $base_path/ExternalAtlases/mitra $dest_path/ExternalAtlases
    if [ 1 -eq 0 ] ; then
	echo -n ''
    fi
    ./LibManager.pl $base_path/Brain/Mus_Musculus/mouse_chass_images/dti $dest_path/Brain
    ./LibManager.pl $base_path/Brain/Mus_Musculus/whs_atlas/dti101 $dest_path/Brain


fi
}

main;
exit;
1;



