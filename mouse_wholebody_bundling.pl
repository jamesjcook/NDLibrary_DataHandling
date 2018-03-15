#!/usr/bin/perl
use strict;
use warnings;

use Env qw(RADISH_PERL_LIB );
use lib split(':',$RADISH_PERL_LIB);
require Headfile;
require pipeline_utilities;
#use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc $debug_val $debug_locator);# debug_val debug_locator);
use civm_simple_util qw(mod_time load_file_to_array sleep_with_countdown $debug_val $debug_locator);

my $test_mode=1;
my $reduce_source="/Volumes/DataLibraries/001Mouse_Body";
my $partial_dest="/Volumes/DataLibraries/_AppStreamLibraries";
my $bundle_setup="$partial_dest/BundleSetup";

###
# Look at Source , get version and lib name so we can set variable dest
my ($ptxt,$version,$LibName);
{
    my @fa;
    load_file_to_array("$reduce_source/lib.conf",\@fa);
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
        #print("$reduce_source/lib.conf:".scalar(@pathlist)."\n".join(':',@pathlist)."\n");
        ($ptxt,$version)=split('=',$pathlist[$#pathlist]);
        $version="_".trim($version);
    } else {
        $version="";
    }
    if (scalar($#namelist)>-1){
        #print("$reduce_source/lib.conf:".scalar(@namelist)."\n".join(':',@namelist)."\n");
        ($ptxt,$LibName)=split('=',$namelist[$#namelist]);
        $LibName=lc(trim($LibName));
    } else {
        $LibName="";
    }
    #print("LibName is $LibName\n");
    #print("Version is $version\n");
}
###

my $conv_source="";#/Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain";
my @sdirs = File::Spec->splitdir( $reduce_source );
if ($LibName eq "" ){
    $LibName=$sdirs[-1];
} else {
    #print("LibName is set to $LibName, defacto alt would be $sdirs[-1]\n");
}
my $reduce_dest="$partial_dest/DataLibraries_$LibName$version/$sdirs[-1]";
my @ddirs = File::Spec->splitdir( $reduce_dest );

while($sdirs[$#sdirs] eq $ddirs[$#ddirs] && $#sdirs>=0 && $#ddirs>=0){
    my $d1=pop(@sdirs);
    my $d2=pop(@ddirs);
}
#print "i$conv_source";
$conv_source=File::Spec->catdir(@ddirs);
#print " o$conv_source\n";

my $conv_dest="${conv_source}_nhdr"; # THIS SHOULD NOT END IN SLASH!!(rsync)
my $bundle_dest="$partial_dest/Bundle_${LibName}${version}_nhdr";

### 
# Perform reduciton using LibManager, with high debugging.
my $cmd="";
$cmd="./LibManager.pl -d45 $reduce_source $reduce_dest";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=1;
###

###
# Create _nhdr version of library, cloning all the meta data
#  --exclude *tif , Switched to included tif files.
$cmd="rsync --exclude nrrd --exclude *nii* --exclude *nhdr --exclude *gz* --delete -axv $conv_source/ $conv_dest";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=2;

###
# Convert data files into _nhdr library using LibConv
$cmd="./LibConv.pl $conv_source $conv_dest";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=3;
###


###
# strip comments from conf files
$cmd='sed -i \'\' \'/^[[:space:]]*#/d;s/#.*//\' '."\$(find $conv_dest -name lib.conf -type f)";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=4;
###

###
# remove backup (bak) files
$cmd="find $conv_dest -name \"*.bak\" -type f -exec rm {} \\; -print";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=5;
###

###
# bundling - mkdir
if( ! -d $bundle_dest) {
    # Make sure directoy is avaiable
    use File::Path qw(make_path);
    my %dir_opts=('chmod' => 0777);
    if ( ! -d $bundle_dest ) {
        print("\tmkdir -p $bundle_dest\n");
        make_path($bundle_dest,\%dir_opts);# if $debug_val<50;
    }   
}
#

### 
# bundling - find versioned data. 
$cmd="find $conv_dest -name \"v*\" -type d -print";
print("Finding data with comamnd($cmd).\n");
print("\n---\nVersionied Data:\n---");
my @bundles=qx($cmd);
chomp(@bundles);

print("\n\n---\nBundles_to_create:\n---\n\t".join("\n\t",@bundles)."\n");
#

###
# bundling - bundle up each versioned piece
use Cwd;
my $code_dir = getcwd();
use Scalar::Util qw(openhandle);
my $force_path_libname=1;
my $output_path;
foreach (@bundles) {
    my $lib_name;
    my $version;

    # Get the libraries displayname from lib.conf if it has one.
    # for some the lib.conf is deeper in the directory chain. Not sure how i want to handle that.
    my $file = "$_/lib.conf";
    use Carp;
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
    use File::Spec qw(splitdir);
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
    chdir $conv_dest;
    # need to shorten $output_path by $conv_dest
    my $pl=length($_);
    $_=~s:^$conv_dest/::x;
    if( $pl ==  length($_)) {
        die "Path reduction failed!";
    } else{
        print("  rel_path:$_\n");}
    $cmd="zip $testing -o -v -FS -r $output_path $_";
    print("cd $conv_dest;$cmd;cd $code_dir;\n");# show command to user
    run_cmd($cmd) if $test_mode<=6; 
    chdir $code_dir;
}
#

###
# bundling - non-versioned portions
$output_path="$bundle_dest/Mouse_Body_examples.zip";
print("Bundling! -> $output_path\n") if $test_mode<=6;
chdir $conv_dest;
$cmd="zip -o -v -FS -r $output_path 000ExternalAtlasesBySpecies ExternalAtlases";
print("cd $conv_dest;$cmd;cd $code_dir;\n");# show command to user
run_cmd($cmd) if $test_mode<=6;

###
# bundling add setup code.
$cmd="rsync -axv $bundle_setup/ $bundle_dest";
print($cmd."\n");
run_cmd($cmd) if $test_mode<=8;
# 

### 
# bundling - put whole thing in zip
# Should pick the library item number from the

$output_path="$partial_dest/CIVM-17005${version}.zip";
#use File::Spec qw(splitdir);
#my @bparts = File::Spec->splitdir( $bundle_dest );
#$bundle_nme=pop(@bparts);
$cmd="zip -o -v -FS -r $output_path *";# cut bundle dest down to just final part. 
print("cd $bundle_dest;$cmd;cd $code_dir;\n");# show command to user
chdir $bundle_dest;
run_cmd($cmd) if $test_mode<=9;



# 
print("Bundling Complete for $LibName\n\t # -> $bundle_dest ");
exit;
sub run_cmd {
    my ($cmd)=@_;
    open(my $fh, "-|", "$cmd");
    while ( openhandle($fh) && (my $line = <$fh>)) {
        print("\t".$line); }
    
    close($fh);

}
