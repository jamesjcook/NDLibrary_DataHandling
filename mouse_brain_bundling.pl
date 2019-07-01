#!/usr/bin/perl
# an automatic data cleaner operating in stages
# Taking an item in source_tree(source_tree, branch_name)
# 1) make a new tree (reduced_tree) with only that item and branches/leaves it relies on.
# 2) replicate all meta data from reduced tree into converted tree.
# 3) convert reduced_tree image files into nhdr files in converted tree which have gray levels set in their nhdrs.
# 4) bundle up each reasonably divisible part of this library
# 5) grab setup code
# 6) bundle everything together in one zip.
# Horray! We're almost functionized at this point with the "critical" vars
# being set at the front of the script. If those were abstracted into a file
# to start with, we could make this a generic "LibBundler.pl"
#
use strict;
use warnings;

use Carp;
use Cwd;
use File::Path qw(make_path);
use File::Spec qw(splitdir);
use Scalar::Util qw(openhandle);

use Env qw(RADISH_PERL_LIB );
use lib split(':',$RADISH_PERL_LIB);
use Headfile;
use pipeline_utilities;
#use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc $debug_val $debug_locator);# debug_val debug_locator);
#use civm_simple_util qw(mod_time load_file_to_array sleep_with_countdown $debug_val $debug_locator);
use civm_simple_util qw(trim file_mod_extreme find_file_by_pattern load_file_to_array write_array_to_file);
# for each unit of work, skip ahead
# once data is "right" it can be safely skipped every time.
# That is 8,
my $test_mode=12;
# stage stop, as listed in header commnet
# choices, end, convert_tree, reduced_tree
# test_mode must be  <=5 for convert and <=2 for reduce
my $stage_stop="end";
# the source tree is where our item lives
# when running from mac land in the old days "/Volumes/DataLibraries";
my $source_tree="/L/Libraries";

# this is a branch or the input tree
my $branch_name="000Mouse_Brain";
my $source_branch="$source_tree/$branch_name";

# this is a forest of trees which are not related and should not affect one another.
# We're trying to grab a single branch of our input tree, and make a new tree in this forest for just that branch.
# There are other items in this forest which should not be affected by our work here.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamLibraries";
my $dest_forest="/L/AppStreamLibraries";

# One thing in our forest is this bundle setup stuff.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamSupport/BundleSetup";
my $bundle_setup="/D/Dev/AppStreamSupport/BundleSetup";
my $setup_components="Setup"; # dir in bundle_setup we stuff components.

# One thing in our forest is this exec_cache.
# when running from mac land in the old days "/Volumes/DataLibraries/_Software/";
#  /Volumes/l$/Other/Installs/
# S is civmbigdata Software(mounted to S:/)
my $installer_store="/S/InteractivePublishing";
# this refers to our "cold storage" location for the different versions of the applicaiton.
# We could use "latest", a special keyword to capture the newest installer,
# its will be literally the latest file in the installer store, so it's not 100% reliable.
# Here we're specify the proper folder directly.
my $installer_version="b15";

# where our result complete bundle will end up.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamBundles";
my $bundle_forest="/L/AppStreamBundles";


###
# settings for bundle installer.
# used at very end.
my %sv;
$sv{'LibItemNumber'}="CIVM-17001";
$sv{'LibIndex'}="$branch_name";
$sv{'WinAppBundleName'}="AtlasViewer-0.4.0-e88a129";#-da2b5d2"; #-win-amd64_20171107
$sv{'WinProgramVersion'}="20190624";#"20171107";
$sv{'WinExtensionBundle'}="Slicer-4.9.0-2018-07-12-win-amd64_extensions";
$sv{'MacExtensionBundle'}="Slicer-4.9.0-2018-07-12-macosx-amd64_extensions";


###
# Look at Source, get version and lib name so we can set variable dest
my ($ptxt,$version,$LibName);
{
    my @fa;
    load_file_to_array("$source_branch/lib.conf",\@fa);
    chomp(@fa);
    #my @redulist=grep(/^(?:\s)*(Path=v[0-9]{4}(?:-[0-9]{2}){2})/,@fa);
    my @pathlist;
    my @namelist;
    for my $line (@fa) {
        if(  $line =~ /^(?:\s)*(Path[\s]*=[\s]*v[0-9]{4}(?:-[0-9]{2}){2})([\s]*[#].*)?$/x ) {
            push(@pathlist,$1);
            print("p$1\n");
        }
        elsif(  $line =~ /^(?:\s)*(LibName[\s]*=[\s]*[\w]+)([\s]*[#].*)?$/x ) {
            push(@namelist,$1);
            print("n$1\n");
        }
    }

    if (scalar(@pathlist)>0){
        #print("$source_branch/lib.conf:".scalar(@pathlist)."\n".join(':',@pathlist)."\n");
        ($ptxt,$version)=split('=',$pathlist[$#pathlist]);
        $version="_".trim($version);
    } else {
        print("No path-version found\n");
        $version="";
    }
    if (scalar(@namelist)>0){
        #print("$source_branch/lib.conf:".scalar(@namelist)."\n".join(':',@namelist)."\n");
        ($ptxt,$LibName)=split('=',$namelist[$#namelist]);
        $LibName=lc(trim($LibName));
    } else {
        print("No name specified\n");
        $LibName="";
    }
    #print("LibName is $LibName\n");
    #print("Version is $version\n");
}
#die "L:$LibName, V:$version";
###


###
# Get the conversion source, and dest, and bundle dest
# this is complicated becuase of different conventions for index data and the full library tree.
# In simple terms, the index folder is inside the full library tree, so when we're reducing,
# we take an index, and place it inside a new full tree,
# that makes the inputs to LibManager INDEX_PATH/SINGLE_ITEM_PATH, NEW_FULL_TREE
#
# After that the conversion operates on a full tree without sensitivity to lib.conf files.
# So its inputs get to be simpler, and so does that part to fhte work.
#
my $conv_source="";#/Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain";
my @sdirs = File::Spec->splitdir( $source_branch );
if ($LibName eq "" ){
    $LibName=$sdirs[-1];
} else {
    #print("LibName is set to $LibName, defacto alt would be $sdirs[-1]\n");
}
my $reduced_tree="$dest_forest/DataLibraries_$LibName$version";
my $dest_branch="$reduced_tree/$sdirs[-1]";

if ( 0 ) {
    my @ddirs = File::Spec->splitdir( $dest_branch );
    print("Dir trimming source and dest\n".
          "\t\t$source_branch\n".
          "\t\t$dest_branch\n");
    while($sdirs[$#sdirs] eq $ddirs[$#ddirs] && $#sdirs>=0 && $#ddirs>=0){
        my $d1=pop(@sdirs);
        $d1=pop(@ddirs);
        print("\t$d1\n");
    }
    #print "i$conv_source";
    $conv_source=File::Spec->catdir(@ddirs);
    #print " o$conv_source\n";
}
$conv_source=$reduced_tree;# In the future this var may be eliminated to stream line things.
my $converted_tree="${conv_source}_nhdr"; # THIS SHOULD NOT END IN SLASH!!(rsync)
my $bundle_dest="$dest_forest/Bundle_${LibName}${version}_nhdr";
###

####
# BEGIN WORK.
####
print("Outputs will be based in $dest_forest\n".
      #"reducing $source_branch -> $dest_branch\n".
      "reducing $branch_name in $source_tree into $reduced_tree\n".
      #"will convert $conv_source -> $converted_tree\n".
      "which we'll convert to $converted_tree\n".
      #"will bundle $converted_tree -> $bundle_dest\n");
      "to be bundled into $bundle_dest\n");
###
# Perform reduciton using LibManager, with high debugging.
# WARNING LibManager is DESTRUCTIVE of the dest!
my $cmd="";
# We're changing over libmanager to have a simpler convention and therefore be less confusing.
# new convention is source_tree,  reduced_tree, item
#$cmd="./LibManager.pl -d45 $source_branch $dest_branch";
$cmd="./LibManager.pl -d45 $source_tree $reduced_tree $branch_name";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=1;
###
die if $stage_stop eq "reduced_tree";
#die "post libmanager";

###
# Create _nhdr version of library, cloning all the meta data
#  --exclude *tif , Switched to included tif files.
$cmd="rsync --exclude nrrd --exclude *nii* --exclude *nhdr --exclude *gz* --delete -axv $conv_source/ $converted_tree";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=2;
###
#die "post nhdr_base clone";

###
# Convert data files into _nhdr library using LibConv
$cmd="./LibConv.pl $reduced_tree $converted_tree";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=3;
###
#die "post libconv";

###
# strip comments from conf files
$cmd='sed -i\'\' \'/^[[:space:]]*#/d;s/#.*//\' '."\$(find $converted_tree -name lib.conf -type f)";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=4;
###

###
# remove backup (bak) files
$cmd="find $converted_tree -name \"*.bak\" -type f -exec rm {} \\; -print";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=5;
###
die if $stage_stop eq "convert_tree";
###
# bundling - mkdir
my %dir_opts=('chmod' => 0777);
if( ! -d $bundle_dest) {
    # Make sure directoy is avaiable
    if ( ! -d $bundle_dest ) {
        print("\tmkdir -p $bundle_dest\n");
        make_path($bundle_dest,\%dir_opts);# if $debug_val<50;
    }
}
#

###
# bundling - find versioned data.
$cmd="find $converted_tree -name \"v*\" -type d -print";
print("Finding data with comamnd($cmd).\n");
print("\n---\nVersionied Data:\n---");
my @bundles=qx($cmd);
chomp(@bundles);

print("\n\n---\nBundles_to_create:\n---\n\t".join("\n\t",@bundles)."\n");
#
# die "pre bundlerun";

###
# bundling - bundle up each versioned piece
my $code_dir = getcwd();

my $force_path_libname=1;
my $output_path;
if ( ! -d File::Spec->catfile($bundle_dest,'Data') ) {
    make_path(File::Spec->catfile($bundle_dest,'Data'),\%dir_opts); }
foreach (@bundles) {
    my $lib_name;
    my $version;

    # Get the libraries displayname from lib.conf if it has one.
    # for some the lib.conf is deeper in the directory chain. Not sure how i want to handle that.
    my $file = "$_/lib.conf";
    open my $fh, '<', $file or carp "Could not open '$file' $!\n";
    while ( openhandle($fh) && (my $line = <$fh>)) {
        chomp $line;
        if ($line=~ /^LibName=(.*)$/){
            #print("LibName:$1\n");
            $lib_name=$1;
        }
    }
    close($fh);
    # Get the path component names,
    my @dirs = File::Spec->splitdir( $_ );
    $version=pop(@dirs);
    if ( ! defined $lib_name || $force_path_libname) {
        #use File::Basename;
        #$lib_name = basename($_);
        #print("Base:$lib_name\n");
        #($volume,$directories,$file) =
        #File::Spec->splitpath( $path );
        $lib_name=pop(@dirs);
        #print("parname:$lib_name\n");
    }

    # -o is set archive modify time to newest file time
    # -sc prints command line as zip sees it
    # -T tests the archive ONLY FOR EXISTING ZIPE!
    # -r operates on folders recursively.
    $output_path=File::Spec->catfile($bundle_dest,'Data',"${lib_name}_$version.zip");
    my $testing="-sc"; # when on, will not do zip
    $testing="";
    print("Bundling! -> $output_path\n") if $test_mode<=6;
    chdir $converted_tree;
    # need to shorten $output_path by $converted_tree
    my $pl=length($_);
    $_=~s:^$converted_tree/::x;
    if( $pl ==  length($_)) {
        die "Path reduction failed!";
    } else{
        print("  rel_path:$_\n");}
    # mac specific zip command
    #$cmd="zip $testing -o -v -FS -r $output_path $_";
    # git-sdk-able zip command
    $cmd="zip $testing -o -v -FS -r $output_path $_";
    print("cd $converted_tree;$cmd;cd $code_dir;\n");# show command to user
    run_and_watch($cmd) if $test_mode<=6;
    chdir $code_dir;
}
#

###
# bundling - non-versioned portions
if ( 0 ) { # TEMPORARILY DISABLED BECAUSE WE DONT HAVE EXAMPLES SET UP
$output_path=File::Spec->catfile($bundle_dest,'Data',$sv{'LibItemNumber'}."_examples.zip");
#$output_path="$bundle_dest/Human_Brainstem_examples.zip";
print("Bundling! -> $output_path\n") if $test_mode<=7;
chdir $converted_tree;
$cmd="zip -o -v -FS -r $output_path 000ExternalAtlasesBySpecies ExternalAtlases";
print("cd $converted_tree;$cmd;cd $code_dir;\n");# show command to user
run_and_watch($cmd) if $test_mode<=7;
}

###
# bundling add setup code.
# omit git directories or change the fetch command to a shallow clone?
# Lets do things the "cool way" Lets use rsync to omit git directories.
$cmd="rsync -axv --exclude '*ffs_db' --exclude 'test*' --exclude 'prototype*' --exclude 'example_*' --exclude '.git*' --exclude '*.bak' --exclude '*.md' --exclude '*~' $bundle_setup/ $bundle_dest";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=8;
#

###
# bundling - get latest exec, or specified version.
#
#my @b_dir_path = File::Spec->splitdir( $bundle_setup );
# BundleSetup word missing from bundle_dest, get with splitdir, using b_dir_path end...
# Except thats not hwo we're doing it, we're using just the plain Setup word... which is part of bundlesetup.
my $bundle_app_support=File::Spec->catdir(($bundle_dest,$setup_components));
# do a print perhaps?
#catdir(($bundle_dest,$b_dir_path[$#b_dir_path]));
# if installer_version=latest, resolve to last file in folder.
my $av_store=File::Spec->catdir(($installer_store,"AtlasViewer","*"));
if ( $installer_version eq "latest") {
    #print("getting latest from $av_store\n");
    #my @versions=find_file_by_pattern($av_store,'.*');
    my @version_dirs=glob("$av_store");
    my $newest=file_mod_extreme(\@version_dirs,"new");
    my @td = File::Spec->splitdir( $newest );
    $installer_version=$td[-1];
    print("Latest:$installer_version\n");
}
    #print("getting latest from $av_store\n");
my $installer_dir=File::Spec->catdir(($installer_store,"AtlasViewer",$installer_version));
$cmd="rsync -axv $installer_dir $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;
$cmd="touch ".File::Spec->catdir(($bundle_app_support,"$installer_version.ver"));
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;
# potentially remove old *.ver files and maybe old ver dirs...
my @old_versions=grep(!/$installer_version.ver/, glob($bundle_app_support."/*.ver"));
if ( scalar(@old_versions)>0 ) {
    print("Found old versions(".join(",",@old_versions).")\n");
    foreach (@old_versions) {
        $_ =~s/(.*)[.]ver$/$1/g;
        if ( $_ ne $bundle_app_support
         && -e $_ ) {
            print "should remove $_ and it's ver file\n";
            $cmd="rm -fr $_ $_.ver";
            print($cmd."\n");
            run_and_watch($cmd) if $test_mode<=10;
        }
    }
}

###
# bundling - get settings
my $settings_dir=File::Spec->catdir(($installer_store,"AtlasViewer","Settings"));
$cmd="rsync -axv $settings_dir $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=11;

###
# bundling - get extensions
#S:\win\Image_Viewers_and_Editors\slicer\4
my $ext_file=File::Spec->catdir(($installer_store,"Slicer","Slicer-4.9.0-2018-07-12-win-amd64_extensions.7z"));
$cmd="cp -np $ext_file $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=11;

###
# bundling - get qt5 missing bits.
# bunled the whole sha bang into _bundle.7z,
# cut it down to just the missing quick modle in patch.
# may need more extensive testing to find other missing bits.
my $qt_file=File::Spec->catdir(($installer_store,"AtlasViewer","AV_QT5_patch.7z"));
$cmd="cp -p $qt_file $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=11;


###
# bundling - finalize whole thing into singular zip
# Should pick the library item number from the

#
# encode sv hash to the setup vars file.
#
my $setup_vars=File::Spec->catfile($bundle_dest,"setup_vars.txt");
# setup vars are a special name=value name2=value2 ENDECHO single line text file for the installer script.
if ( -e $setup_vars ) {
    my @slines=();
    my $setup_vars_modified=0;
    load_file_to_array($setup_vars,\@slines);
    if( scalar(@slines)>1) {
        warn("extra lines in the setup vars");
    }
    if (scalar(@slines)==0) {
        die "Error reading setup vars proto";
    }
    my @vars=split(' ',$slines[0]);
    for(my $vn=0;$vn<scalar(@vars);$vn++) {
        my ($na,$val)=split("=",$vars[$vn]);
        if ( defined $na  ) {
            if (defined $val  ) {
                if ( exists($sv{$na}) ) {
                    if ( $val ne $sv{$na}) {
                        print("Updating $na with $sv{$na} \n");
                        $val=$sv{$na};
                        $setup_vars_modified=1;
                    }
                }
                $vars[$vn]="$na=$val";
            } else {
                $vars[$vn]="$na";
            }
        }
        if ( $vars[$vn] eq 'ENDECHO' ) {
            $vars[$vn]=" ENDECHO"; }
    }
    if ($setup_vars_modified == 1) {
        $slines[0]=join(' ',@vars);
        write_array_to_file($setup_vars,\@slines);
    }
    $output_path=File::Spec->catfile($bundle_forest,"$sv{LibItemNumber}${version}.zip");
    #use File::Spec qw(splitdir);
    #my @bparts = File::Spec->splitdir( $bundle_dest );
    #$bundle_nme=pop(@bparts);
    $cmd="zip -o -v -FS -r $output_path *";# cut bundle dest down to just final part.
    print("cd $bundle_dest;$cmd;cd $code_dir;\n");# show command to user
    chdir $bundle_dest;
    run_and_watch($cmd) if $test_mode<=12;
    print("Bundling Complete for $LibName\n\t # -> $bundle_dest \n\n # -> $output_path \n");
} else {
    print("No setup_vars at $setup_vars!, Will not create new final zip!");
}

#

exit;
sub run_cmd {
    print("start $cmd\n");die;
    return run_and_watch(@_,"\t");
}
1;
