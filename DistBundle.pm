
#
# simplified distribution bundler for our python viewer
# since pythonviewer has greatly integrated simplifier
# much of the perl work for our service based offering is
# not necessary.
package DistBundle;

use strict;
use warnings;

use English;
use Carp;
use Cwd;
use File::Basename;
use File::Path qw(make_path);
use File::Spec qw(splitdir);
use Scalar::Util qw(openhandle);

use Env qw(RADISH_PERL_LIB );
use lib split(':',$RADISH_PERL_LIB);
#use Headfile;
use pipeline_utilities;
#use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc $debug_val $debug_locator);# debug_val debug_locator);
#use civm_simple_util qw(mod_time load_file_to_array sleep_with_countdown $debug_val $debug_locator);
use civm_simple_util qw(trim file_mod_extreme find_file_by_pattern load_file_to_array write_array_to_file sleep_with_countdown);

BEGIN {
    use Exporter;
    our @ISA = qw(Exporter); # perl critic wants this replaced with use base; not sure why yet.
    #@EXPORT_OK is prefered, as it markes okay to export, HOWEVER our code is dumb and wants all the pipe utils!
    our @EXPORT_OK = qw(
    dist_bundle
    );
}

my $ZIP="zip";
my $ZIP_ENV="ix";
# to support windows, pulled a minimal msys2zip dist together.
# 'D:\Dev\AppStreamSupport\msys2zip\msys2zip\usr\bin\zip.exe'
# will use which to figure out what one.
my @ziploc=run_and_watch("which $ZIP","",0);
chomp(@ziploc);
if(!scalar(@ziploc) || ! -e $ziploc[0]){
    @ziploc=run_and_watch("cygpath -m '".'D:\Dev\AppStreamSupport\msys2zip\msys2zip\usr\bin\zip.exe'."'");
    chomp(@ziploc);
    if(scalar(@ziploc) && -e $ziploc[0]){
        $ZIP=$ziploc[0];
        $ZIP_ENV="win";
    } else {
        die "CANNOT find zip";
    }
}

# simplified disrtibution setup
sub dist_bundle {
    my ($or,$dist_lib,$dest_zip) = @_;
    my %o=%$or;
    #Data::Dump::dump(\%o);die;
    if(! defined $dest_zip || $dest_zip eq "") {
        $dest_zip=$dist_lib.".zip"; }
    #dist_simplify();
    dist_add_viewer($o{"viewer_code"},$dist_lib);
    dist_add_setup($o{"bundle_setup"},$dist_lib);
    #my($sevenZdir,$sevenZname,$bundle_app_support)=@_
    #my $compressor_path=File::Spec->catdir($o{"sevenZdir"}.$o{"sevenZname"});
    #dist_add_decompressor($compressor_path,$dist_lib);
    dist_zip($dist_lib,$dest_zip);
    print("Done!");
}

sub dist_add_viewer {
    my($view_src,$bundle_dest)=@_;
    my $cmd;
    # should also compare latest code with tags, and tag version, then push tag to remote
    my $view_dest=File::Spec->catdir($bundle_dest,basename($view_src));
    if( ! -e $view_dest ) {
        $cmd="(cd $bundle_dest && git clone --recurse-submodules $view_src $view_dest)";
    } else {
        $cmd="(cd $view_dest && git stash && git pull && git stash pop; git submodule update --init --recursive)";
    }
    print($cmd."\n");
    run_and_watch($cmd);
}

sub dist_add_setup {
    my($bundle_setup,$bundle_dest)=@_;
    my $cmd;
    # we stage the setup code because it doesnt need any git linkage back,
    # setup updates are well out of spec.
    #my $setup_assembly="$dest_forest/${LibName}_2setup${version}"; # temporary setup location
    my $setup_assembly=$bundle_dest."_setup_staging";
    ###
    # bundling create compele setup assembly code.
    if( ! -e $setup_assembly ) {
        $cmd="(cd $bundle_dest && git clone --recurse-submodules $bundle_setup $setup_assembly)";
    } else {
        $cmd="(cd $setup_assembly && git stash && git pull && git stash pop; git submodule update --init --recursive)";
    }
    print($cmd."\n");
    run_and_watch($cmd);
    #

    ###
    # insert the setup assembly into the bundle dir.
    # omit git directories or change the fetch command to a shallow clone?
    # Lets do things the "cool way" Lets use rsync to omit git directories.
    #$cmd="rsync -axv --exclude '*ffs_db' --exclude 'test*' --exclude 'prototype*' --exclude 'example*' --exclude '.git*' --exclude '*.bak'  --exclude '*.last' --exclude '*.md' --exclude '*~' $setup_assembly/ $bundle_dest/";
    #print($cmd."\n");die "testing";
    #run_and_watch($cmd);
    slop_sync($setup_assembly, $bundle_dest,qw( *ffs_db test* prototype* example* .git* *.bak  *.last *.md *~));
}

sub dist_add_decompressor {
    my($sevenZdir,$sevenZname,$bundle_app_support)=@_;
    my $cmd;
###
# bundling - get 7z
$cmd="rsync -axv $sevenZdir/ ".File::Spec->catdir($bundle_app_support,"$sevenZname")."/";
print($cmd."\n");
run_and_watch($cmd);
}

sub slop_sync {
    # limited use case rsync replacement
    my ($src,$dst,@exclusions)=@_;
    if( ! defined $dst || $dst eq "" || length $dst < 15 )  {
        print("destination is short, cowardly slop_sync abandon");
        return;
    }
    my $cmd;
    $cmd="cp -rTpvu $src $dst";
    print($cmd."\n");
    run_and_watch($cmd);
    if(! scalar(@exclusions)) {
        return;
    }
    my $excluded='-name "'.join('" -or -name "',@exclusions).'"';
    #$cmd="find $src $excluded -exec rm {} \+";
    $cmd="find $src $excluded |sed 's|".$src."|".$dst."|'";
    print($cmd."\n");
    my @components = run_and_watch($cmd);
    chomp(@components);
    if(! scalar(@components)) {
        return;
    }
    $cmd="rm -rf ".join(" ",@components);
    print($cmd."\n");
    run_and_watch($cmd);
}

sub dist_zip {
    my($dist_lib,$dest_zip)=@_;
    my $cmd;
    #my($lib_name,$bundle_dest,$test_mode,$converted_tree,$code_dir,$output_path,$version);
    # -o is set archive modify time to newest file time
    # -sc prints command line as zip sees it
    # -T tests the archive ONLY FOR EXISTING ZIPE!
    # -r operates on folders recursively.
    #$output_path=File::Spec->catfile($bundle_dest,'Data',"${lib_name}_$version.zip");
    my $testing="-sc"; # when on, will not do zip
    $testing="";
    print("Bundling! -> $dest_zip\n");
    # need to shorten $dest_zip by $dist_lib
    #my $pl=length($_);
    #$_=~s:^$dist_lib/::x;
    #if( $pl ==  length($_)) {
    #    die "Path reduction failed!";
    #} else{
    #    print("  rel_path:$_\n");}
    # mac specific zip command
    #$cmd="zip $testing -o -v -FS -r $dest_zip .* *;
    # git-sdk-able zip command
    if($ZIP_ENV ne "win"){
        $cmd="$ZIP $testing -o -v -FS -r $dest_zip *";
        #print("pushd \$PWD;cd $dist_lib;$cmd;popd;\n");# show command to user
        $cmd='pushd $PWD;'.$cmd.';popd';
    } else {
        ($dest_zip)=run_and_watch("cygpath -m '$dest_zip'");
        chomp($dest_zip);
        $cmd="$ZIP $testing -o -v -FS -r $dest_zip *";
        my $tmp_scr="zip.bat";
        unlink $tmp_scr;
        print(" ZIP cmd : $cmd\n");
        write_array_to_file($tmp_scr,[$cmd."\r\n"]);
        $cmd='d=$PWD; pushd $PWD; cd '.$dist_lib.'; $(cygpath -m $d/'.$tmp_scr.'); popd';
    }
    print($cmd."\n");
    die "testing";
    run_and_watch($cmd);
}

1;
