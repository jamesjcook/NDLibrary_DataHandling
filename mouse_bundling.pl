#!/usr/bin/perl
use strict;
use warnings;

my $test_mode=6;

my $reduce_source="/Volumes/DataLibraries/000Mouse_Brain";
my $reduce_dest="/Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain/000Mouse_Brain";

my $cmd="";
$cmd="./LibManager.pl $reduce_source $reduce_dest";
qx($cmd) if $test_mode<=1;
print($cmd."\n");

my $conv_source="/Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain";
my $conv_dest="/Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain_nhdr"; # THIS SHOULD NOT END IN SLASH!!(rsync)
my $bundle_dest="/Volumes/DataLibraries/_AppStreamLibraries/Bundle_mouse_brain_nhdr";


$cmd="rsync --exclude nrrd --exclude *nii* --exclude *nhdr --exclude *gz* --exclude *tif --delete -axv $conv_source/ $conv_dest";
qx($cmd) if $test_mode<=2;
print($cmd."\n");

$cmd="./LibConv.pl /Volumes/DataLibraries/_AppStreamLibraries/DataLibraries_mouse_brain $conv_dest";
qx($cmd) if $test_mode<=3;
print($cmd."\n");

# strip comments
$cmd='sed -i \'\' \'/^[[:space:]]*#/d;s/#.*//\' '."\$(find $conv_dest -name lib.conf -type f)";
qx($cmd) if $test_mode<=4;
print($cmd."\n");

# remove backup (bak) files
$cmd="find $conv_dest -name \"*.bak\" -type f -exec rm {} \\; -print";
qx($cmd) if $test_mode<=5;
print($cmd."\n");


# do bundling
if( ! -d $bundle_dest) {
    # Make sure directoy is avaiable
    use File::Path qw(make_path);
    my %dir_opts=('chmod' => 0777);
    if ( ! -d $bundle_dest ) {
	print("\tmkdir -p $bundle_dest\n");
	make_path($bundle_dest,\%dir_opts);# if $debug_val<50;
    }	
}
# find versioned data.
$cmd="find $conv_dest -name \"v*\" -type d -print";
my @bundles=qx($cmd);
chomp(@bundles);
print($cmd."\n");
print("Bundles_to_create:\n\t".join("\n\t",@bundles)."\n");

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
    #system($cmd) if $test_mode<=6;
    #`$cmd` if $test_mode<=6;
    open($fh, "-|", "$cmd");
    while ( openhandle($fh) && (my $line = <$fh>)) {
	print("\t".$line);
    }
    close($fh);
#} else {
    #print("Exists! -> $output_path\n");
#}
    chdir $code_dir;
}

$output_path="$bundle_dest/Mouse_Brain_examples.zip";
print("Bundling! -> $output_path\n") if $test_mode<=6;
chdir $conv_dest;
$cmd="zip -o -v -FS -r $output_path 000ExternalAtlasesBySpecies ExternalAtlases";
print("cd $conv_dest;$cmd;cd $code_dir;\n");# show command to user
open(my $fh, "-|", "$cmd");
while ( openhandle($fh) && (my $line = <$fh>)) {
    print("\t".$line);
}
close($fh);
