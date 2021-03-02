
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
    if(! exists $o{'setup_doc_suppliments'}){
        $o{'setup_doc_suppliments'}=qw(); }
    #Data::Dump::dump(\%o);die;
    if(! defined $dest_zip || $dest_zip eq "") {
        $dest_zip=$dist_lib.".zip"; }
    #dist_simplify();
    dist_add_viewer($o{"viewer_code"},$dist_lib);
    dist_add_setup($o{"bundle_setup"},$dist_lib, $o{'setup_doc_suppliments'});
    dist_mac_patch($o{"mac_appify"},File::Spec->catdir($dist_lib,"Components","utils"));
    #my($sevenZdir,$sevenZname,$bundle_app_support)=@_
    #my $compressor_path=File::Spec->catdir($o{"sevenZdir"}.$o{"sevenZname"});
    #dist_add_decompressor($compressor_path,$dist_lib);
    dist_zip($dist_lib,$dest_zip);
    print("Done!");
}

sub git_remote_url {
    my($local_repo)=@_;
    my @remote_info=run_and_watch("cd $local_repo && git remote get-url origin");
    chomp(@remote_info);
    @remote_info=grep /[@]/, @remote_info;
    my ($rem_url) = @remote_info;
    return defined $rem_url ? $rem_url : "";
}

sub git_set_origin {
    my($local_repo,$new_origin)=@_;
    #die "Url update $local_repo with $new_origin";
    run_and_watch("cd $local_repo && git remote set-url origin $new_origin");
    return;
}

sub dist_add_viewer {
    my($view_src,$bundle_dest)=@_;
    my $cmd;
    # should also compare latest code with tags, and tag version, then push tag to remote
    my $view_dest=File::Spec->catdir($bundle_dest,basename($view_src));
    if( ! -e $view_dest ) {
        $cmd="(cd $bundle_dest && git clone --recurse-submodules $view_src $view_dest)";
    } else {
        $cmd="(cd $view_dest && git stash && git pull $view_src && git stash pop; git submodule update --init --recursive)";
    }
    print($cmd."\n");
    run_and_watch($cmd);
    # detect if code is local, or remote.
    # if we're local, try to get more remore code, so we could do web udpates if so inclined.
    my $original_remote=git_remote_url($view_src);
    my $cur_remote=git_remote_url($view_dest);
    if($original_remote ne $cur_remote){
        git_set_origin($view_dest,$original_remote);
    }
}

sub dist_add_setup {
    my($bundle_setup,$bundle_dest,@approved_sup)=@_;
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
    #WHOOPS< rsync is PITA on winblows.
    #$cmd="rsync -axv --exclude '*ffs_db' --exclude 'test*' --exclude 'prototype*' --exclude 'example*' --exclude '.git*' --exclude '*.bak'  --exclude '*.last' --exclude '*.md' --exclude '*~' $setup_assembly/ $bundle_dest/";
    #print($cmd."\n");die "testing";
    #run_and_watch($cmd);
    slop_sync($setup_assembly, $bundle_dest,qw( *ffs_db test* prototype* example* *.log *.lnk .git* *.bak  *.last *.md *~ *pyc __pycache__));
    folder_clean($bundle_dest,qw( *.log *.lnk *~ *pyc __pycache__));

    ###
    # Remove any README_X or HELP_X files UNLESS they match approved supplimental material.
    my @supplimental=find_file_by_pattern($bundle_dest,"(README|HELP)_.*[.]txt");
    my @removables;
    if(scalar(@approved_sup)){
        my $a_sup_pat=join("|",@approved_sup);
        @removables=grep !/$a_sup_pat/x, @supplimental;
    } else {
        @removables=@supplimental;
    }
    if(scalar(@removables)){
        if($pipeline_utilities::can_dump){
            Data::Dump::dump(\@removables);
        }else{
        display_complex_data_structure(\@removables);}
        print("Removing unused supplimental README/HELP \n\t"
            .join("\n\t",@removables)."\n");
        sleep_with_countdown(5);
        for my $f (@removables) {
            print("rm $f\n");
            unlink $f;
        }
    }
}

sub dist_mac_patch {
    my ($file, $dest_dir)=@_;
    my $ne=basename $file;
    my $df=File::Spec->catfile($dest_dir,$ne);
    run_on_update("cp -p ".$file." ".$df,[$file],[$df]);
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

sub folder_clean {
    my ($dst, @exclusions)=@_;
    # clean bits of stuff out of a folder.
    my $excluded='-name "'.join('" -or -name "',@exclusions).'"';
    my $cmd="find $dst $excluded";
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

sub dist_setup_vars{
    my ($sv_r,$dist_lib)=@_;
    return;
    my($lib_name,$bundle_dest,$bundle_forest,$test_mode,$converted_tree,$code_dir,$output_path,$version);
    my %sv=%$sv_r;
    #
    # encode sv hash to the setup vars file.
    #
    my $setup_assembly=$dist_lib."_setup_staging";
    my $setup_vars=File::Spec->catfile($setup_assembly,"setup_vars.txt");
    # setup vars are a special name=value name2=value2 ENDECHO single line text file for the installer script.
    if ( !-e $setup_vars ) {
        print("No setup_vars at $setup_vars!, Will not create new final zip!");
        return;
    }
    my @slines=();
    my $setup_vars_modified=0;
    load_file_to_array($setup_vars,\@slines);
    if( scalar(@slines)>1) {
        warn("extra lines in the setup vars");
    }
    if (scalar(@slines)==0) {
        die "Error reading setup vars proto";
    }
    $output_path=File::Spec->catfile($bundle_forest,"$sv{LibItemNumber}${version}.zip");
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
                    delete $sv{$na};
                }
                $vars[$vn]="$na=$val";
            } else {
                $vars[$vn]="$na";
            }
        }
        # Removing the end marker in case there are new vars to add.
        if ( $vars[$vn] eq 'ENDECHO' ) {
            $vars[$vn]=""; }
    }
    # add any new keys (which we know there are by clearing existing as we go)
    my @rem_k=keys %sv;
    for(my $vn=0;$vn<scalar(@rem_k);$vn++) {
        print("Adding new key $rem_k[$vn]\n");
        push(@vars,"$rem_k[$vn]=$sv{$rem_k[$vn]}");
        $setup_vars_modified=1;
    }
    push(@vars," ENDECHO");
    if ($setup_vars_modified == 1) {
        $slines[0]=join(' ',@vars);
        write_array_to_file($setup_vars,\@slines);
    }

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
        # in our win env we do some extra hackadashery because we're hardcoding use of an msys2 zip.
        # git-bash which we routinely run our scripts on under is actualy mingw64, eg inerpolated sys calls
        # we're running msys zip becuase its not interpolated system calls... or so we're led to believe
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
    run_and_watch($cmd);
}

1;
