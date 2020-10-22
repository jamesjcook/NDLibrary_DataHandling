#!/usr/bin/env perl
use strict;
use warnings;

use Carp;

use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path($0));

BEGIN {
    #print("Lib add - ".dirname(abs_path($0))."\n");
}

use DistBundle qw(dist_bundle);

use Env qw(RADISH_PERL_LIB );
use lib split(':',$RADISH_PERL_LIB);
#use Headfile;
use pipeline_utilities;


my %opts;
$opts{"bundle_setup"}="/D/Dev/AppStreamSupport/BundleSetupPy";
$opts{"installer_store"}="/D/Dev/InstallerStore";
$opts{"sevenZname"}="7z1805-extra";
$opts{"sevenZdir"}=File::Spec->catdir($opts{"installer_store"},$opts{"sevenZname"});
$opts{"viewer_code"}=File::Spec->catdir("/h/code","ndLibrarySupport");

# former locationing where we re-created the "curated complete" data on the remote end.
#my $dest_forest="/D/Dev/AppStreamLibraries";
#my $bundle_forest="/D/Dev/AppStreamBundles";

# New simplified distibution model where we adulterate our data files
my $dist_root='D:\Libraries\SimplifiedDistributions';
if($dist_root =~ m/:/){
    # win path cleanup.
    ($dist_root)=run_and_watch("cygpath -u '$dist_root'");
    chomp($dist_root);
}
my $dist_lib=File::Spec->catdir($dist_root,"RatBrain_v2020-10-16");
my $dest_zip=File::Spec->catfile($dist_root,"RatBrain_v2020-10-16.zip");

dist_bundle(\%opts,$dist_lib,$dest_zip)
