#!/usr/bin/env perl
use strict;
use warnings;

use Carp;

use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path($0));

use LibBundle qw(LibBundle);


# test_mode is for each unit of work, skip ahead to a particular unit
# once data is "right" it can be safely skipped every time.
# That is 8,
#  1 - create the reduced tree (stage stop reduced_tree )
#  2 - rsync meta to converted tree
#  3 - convert images from reduced into coverted
#  4 - remove all comments from lib.confs in converted_tree
#  5 - remove and .bak files in converted tree (stage stop converted_tree)
#  6 - create versioned component archives
#  7 - create un-versioned component archives
#  8 - init setup assembly
#  9 - add app installer and ver file
# 10 - clean out old app ver's and installers
# 11 - add settings extensions, qt5 patch, 7z to setup assembly, and rsync assembly to final bundle folder
# 12 - build the final complete zip file
my $test_mode=0;

# stage stop, as listed in header commnet
# choices, end, convert_tree, reduced_tree
# test_mode must be  <=5 for convert and <=2 for reduce
my $stage_stop="reduced_tree";

# the source tree is where our item lives
# when running from mac land in the old days "/Volumes/DataLibraries";
my $source_tree="/D/Libraries";

# this is a branch or the input tree
my $branch_name="010Rat_Brain";
#my $source_branch="$source_tree/$branch_name";

# this is a forest of trees which are not related and should not affect one another.
# We're trying to grab a single branch of our input tree, and make a new tree in this forest for just that branch.
# There are other items in this forest which should not be affected by our work here.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamLibrarie
my $dest_forest="/D/Dev/AppStreamLibraries";

# One thing in our forest is this bundle setup stuff.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamSupport/BundleSetup";
my $bundle_setup="/D/Dev/AppStreamSupport/BundleSetup";

# setup_comonents formerly Setup
my $setup_components="Components"; # dir in bundle_setup we stuff components.

# One thing in our forest is this exec_cache.
# when running from mac land in the old days "/Volumes/DataLibraries/_Software/";
#  /Volumes/l$/Other/Installs/
# S is civmbigdata Software(mounted to S:/)
# Big data is still dead :(
my $installer_store="/D/Dev/InstallerStore";

# this refers to our "cold storage" location for the different versions of the applicaiton.
# We could use "latest", a special keyword to capture the newest installer,
# its will be literally the latest file in the installer store, so it's not 100% reliable.
# Here we're specify the proper folder directly.
my $installer_version="b16";

# where our result complete bundle will end up.
# when running from mac land in the old days "/Volumes/DataLibraries/_AppStreamBundles";
my $bundle_forest="/D/Dev/AppStreamBundles";

# Seven z settings, this could stand improvement later.
my $sevenZname="7z1805-extra";
my $sevenZdir=File::Spec->catdir($installer_store,$sevenZname);


###
# settings for bundle installer.
# used at very end.
my %sv;
$sv{'LibItemNumber'}="CIVM-17003";
$sv{'LibIndex'}="$branch_name";
#$sv{'WinAppBundleName'}="AtlasViewer-0.4.0-e88a129";#-da2b5d2"; #-win-amd64_20171107
#$sv{'WinProgramVersion'}="20190624";#"20171107";
$sv{'WinAppBundleName'}="AtlasViewer-0.4.0-e88a129";#-win-amd64_20171107
$sv{'WinProgramVersion'}="20200506";
$sv{'WinExtensionBundle'}="Slicer-4.9.0-2018-07-12-win-amd64_extensions";
$sv{'MacExtensionBundle'}="Slicer-4.9.0-2018-07-12-macosx-amd64_extensions";
$sv{'sevenZname'}=$sevenZname;

LibBundle($source_tree,$branch_name,
    $dest_forest,
    $bundle_forest,
    $bundle_setup,$setup_components,$installer_store,$installer_version,
    $sevenZdir,$sevenZname,
    \%sv,
    $test_mode,$stage_stop);

exit 0;
