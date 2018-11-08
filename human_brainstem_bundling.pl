#!/usr/bin/perl
# an automatic data cleaner operating in stages
# Taking an item in source_tree(source_tree, branch_name)
# 1) make a new tree (reduced_tree) with only that item and branches/leaves it relies on.
# 2) replicate all meta data from reduced tree into converted tree. 
# 3) convert reduced_tree image files into nhdr files in converted tree which have gray levels set in their nhdrs.
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
require Headfile;
require pipeline_utilities;
#use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc $debug_val $debug_locator);# debug_val debug_locator);
#use civm_simple_util qw(mod_time load_file_to_array sleep_with_countdown $debug_val $debug_locator);
use civm_simple_util qw(find_file_by_pattern);

my $test_mode=0;
# the source tree is where our item lives
my $source_tree="/Volumes/DataLibraries";

# this is a branch or the input tree
my $branch_name="040Human_Brainstem";
my $source_branch="$source_tree/$branch_name";

# this is a forest of trees which are not related and should not affect one another.
# We're trying to grab a single branch of our input tree, and make a new tree in this forest for just that branch.
# There are other items in this forest which should not be affected by our work here. 
my $dest_forest="/Volumes/DataLibraries/_AppStreamLibraries";

# One thing in our forest is this bundle setup stuff.
my $bundle_setup="/Volumes/DataLibraries/_AppStreamSupport/BundleSetup";
my $setup_components="Setup"; # dir in bundle_setup we stuff components.

# One thing in our forest is this exec_cache.
my $installer_store="/Volumes/DataLibraries/_Software/";
my $installer_version="latest";

# where our result complete bundle will end up.
my $bundle_forest="/Volumes/DataLibraries/_AppStreamBundles";

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
            #print("p$1\n");
        }
        elsif(  $line =~ /^(?:\s)*(LibName[\s]*=[\s]*[\w]+)([\s]*[#].*)?$/x ) {
            push(@namelist,$1);
            #print("n$1\n");
        }
    }

    if (scalar($#pathlist)>-1){
        #print("$source_branch/lib.conf:".scalar(@pathlist)."\n".join(':',@pathlist)."\n");
        ($ptxt,$version)=split('=',$pathlist[$#pathlist]);
        $version="_".trim($version);
    } else {
        $version="";
    }
    if (scalar($#namelist)>-1){
        #print("$source_branch/lib.conf:".scalar(@namelist)."\n".join(':',@namelist)."\n");
        ($ptxt,$LibName)=split('=',$namelist[$#namelist]);
        $LibName=lc(trim($LibName));
    } else {
        $LibName="";
    }
    #print("LibName is $LibName\n");
    #print("Version is $version\n");
}
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
#die "post libmanager";

###
# Create _nhdr version of library, cloning all the meta data
#  --exclude *tif , Switched to included tif files.
$cmd="rsync --exclude nrrd --exclude *nii* --exclude *nhdr --exclude *gz* --delete -axv $conv_source/ $converted_tree";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=2;

###
# Convert data files into _nhdr library using LibConv
$cmd="./LibConv.pl $reduced_tree $converted_tree";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=3;
###

###
# strip comments from conf files
$cmd='sed -i \'\' \'/^[[:space:]]*#/d;s/#.*//\' '."\$(find $converted_tree -name lib.conf -type f)";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=4;
###

###
# remove backup (bak) files
$cmd="find $converted_tree -name \"*.bak\" -type f -exec rm {} \\; -print";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=5;
###

###
# bundling - mkdir
if( ! -d $bundle_dest) {
    # Make sure directoy is avaiable
    my %dir_opts=('chmod' => 0777);
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

###
# bundling - bundle up each versioned piece
my $code_dir = getcwd();

my $force_path_libname=1;
my $output_path;
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
    $output_path="$bundle_dest/${lib_name}_$version.zip";
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
    $cmd="zip $testing -o -v -FS -r $output_path $_";
    print("cd $converted_tree;$cmd;cd $code_dir;\n");# show command to user
    run_and_watch($cmd) if $test_mode<=6; 
    chdir $code_dir;
}
#

###
# bundling - non-versioned portions
$output_path="$bundle_dest/Human_Brainstem_examples.zip";
print("Bundling! -> $output_path\n") if $test_mode<=6;
chdir $converted_tree;
$cmd="zip -o -v -FS -r $output_path 000ExternalAtlasesBySpecies ExternalAtlases";
print("cd $converted_tree;$cmd;cd $code_dir;\n");# show command to user
run_and_watch($cmd) if $test_mode<=6;


###
# bundling add setup code.
$cmd="rsync -axv $bundle_setup/ $bundle_dest";
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
my $av_store=File::Spec->catdir(($installer_store,"AtlasViewerPackages","*"));
if ( $installer_version eq "latest") {
    #my @versions=find_file_by_pattern($av_store,'.*');
    my @version_dirs=glob("$av_store");
    my $newest=file_mod_extreme(\@version_dirs,"new");
    my @td = File::Spec->splitdir( $newest );
    $installer_version=$td[-1];
    print("Latest:$installer_version\n");
}
my $installer_dir=File::Spec->catdir(($installer_store,"AtlasViewerPackages",$installer_version));
$cmd="rsync -axv $installer_dir $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;
$cmd="touch ".File::Spec->catdir(($bundle_app_support,"$installer_version.ver"));
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;
# potentially remove old *.ver files and maybe old ver dirs...

###
# bundling - get settings
my $settings_dir=File::Spec->catdir(($installer_store,"AtlasViewerPackages","Settings"));
$cmd="rsync -axv $settings_dir $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;

###
# bundling - get extensions
my $ext_file=File::Spec->catdir(($installer_store,"applications","Slicer","Slicer-4.9.0-2018-07-12-win-amd64_extensions.7z"));
$cmd="cp -p $ext_file $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;

###
# bundling - get qt5 missing bits.
my $qt_file=File::Spec->catdir(($installer_store,"AtlasViewerPackages","AV_QT5_bundle.7z"));
$cmd="cp -p $qt_file $bundle_app_support";
print($cmd."\n");
run_and_watch($cmd) if $test_mode<=9;


### 
# bundling - finalize whole thing into singular zip
# Should pick the library item number from the

$output_path="$bundle_forest/CIVM-17002${version}.zip";
#use File::Spec qw(splitdir);
#my @bparts = File::Spec->splitdir( $bundle_dest );
#$bundle_nme=pop(@bparts);
$cmd="zip -o -v -FS -r $output_path *";# cut bundle dest down to just final part. 
print("cd $bundle_dest;$cmd;cd $code_dir;\n");# show command to user
chdir $bundle_dest;
run_and_watch($cmd) if $test_mode<=10;


# 
print("Bundling Complete for $LibName\n\t # -> $bundle_dest \n\n # -> $output_path \n");
exit;
sub run_cmd {
    print("start $cmd\n");die;
    return run_and_watch(@_,"\t");
}
1; 
