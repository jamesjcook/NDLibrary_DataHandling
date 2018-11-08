#!/usr/bin/perl
# LibConv
# converts nii.gz files to nhdr+raw.gz (or raw)

use strict;
use warnings;
use Getopt::Std;
#use File::Basename;
use File::Spec;
use File::Path qw(make_path);
use DateTime;

### CIVM includes
use Env qw(RADISH_PERL_LIB );
use lib split(':',$RADISH_PERL_LIB);
require Headfile;
require pipeline_utilities;
#use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc $debug_val $debug_locator);# debug_val debug_locator);
use civm_simple_util qw(printd mod_time sleep_with_countdown load_file_to_array write_array_to_file $debug_val $debug_locator);
$debug_val=5;


my $can_dump = eval {
    # this little snippit checks if the cool data structure dumping code is available.
    require Data::Dump;
    Data::Dump->import(qw(dump));
    1;
};

#### DATARANGES IS VESTIGIAL CODE.
# It remains for reference of how we did things in the past. 
our  %data_ranges=(
    #'ad'=> [0.0, 0.002],
    'ad'=> [0.0, 0.001], #good for chass
    #'adc'=> [0.0, 0.002],
#    'adc'=> [0.0, 0.001], # good for chass
    #'b0' => [1500, 20000 ],
    'b0' => [1500, 32000 ],# good for chass
    'chi' => [ -0.20, 0.20],# good for chass
    #'dwi' => [1500, 20000 ],
    'dwi' => [1500, 18000 ],# good for chass
    #'fa' => [0.1, 0.7],
    'fa' => [0, 0.7],# good for chass
    'fa_color' => [0, 126],
    'labels' => [0, 255],
    #'gre' => [1500, 20000 ],
    'gre' => [303420, 711234 ],# good for chass, THIS NEEDS TO BE FIXED.
    #'GRE' => [1500, 20000 ],
    #'m0' => [1500,20000],# not used.
    't2star' => [1500, 20000 ],
    #'rd' => [0.0, 0.002],
    'rd' => [0.0, 0.001],# good for chass.
    #    'e1' => [ 0.0, 0.002],
    #    'e2' => [ 0.0, 0.0],
    #    'e3' => [ 0.0,  0.0],
    );
#
# These data states come from simple itk, cutting off the sitk part of each.
#
# https://itk.org/SimpleITKDoxygen/html/namespaceitk_1_1simple.html#ae40bd64640f4014fba1a8a872ab4df98
# 
our  $data_state;
$data_state->{"b0"}->    {"bitdepth"}="Int16";
$data_state->{"dwi"}->   {"bitdepth"}="Int16";
$data_state->{"gre"}->   {"bitdepth"}="Int16";
$data_state->{"t2star"}->{"bitdepth"}="Int16";
#$data_state->{"labels"}->{"bitdepth"}="UInt8";# Not all labels are 8bit, so this is dangerous.

$data_state->{"ad"}->      {"range"}=[  0.0, 0.001]; #good for chass
$data_state->{"e1"}->      {"range"}=$data_state->{"ad"}->      {"range"};

$data_state->{"b0"}->      {"range"}=[ 1500,20000];
$data_state->{"chi"}->     {"range"}=[-0.20,0.20];
$data_state->{"dwi"}->     {"range"}=[ 1500,20000];
#$data_state->{"dwi"}->     {"range"}=[ 500,2000];# more commonly dwi is lower range. Not setting this yet, but maybe in future.
$data_state->{"fa"}->      {"range"}=[  0.0, 0.7];
$data_state->{"fa_color"}->{"range"}=[    0,170];
$data_state->{"gre"}->     {"range"}=[ 1500,20000];
$data_state->{"labels"}->  {"range"}=[    0,255];
$data_state->{"md"}->      {"range"}=[    0, 0.001];
$data_state->{"adc"}->     {"range"}=$data_state->{"md"}->      {"range"};
$data_state->{"t2star"}->  {"range"}=[ 1500,20000];
$data_state->{"rd"}->      {"range"}=[ 0.0, 0.001];

# This ct number is just a guess, and probably a bad one. 
# THis is baed on the naughty whole mouse body ct's which were erroneosuly 8bit
$data_state->{"ct"}->  {"range"}=[    0,30];


exit Main();

sub Main {
    my %opts;
    if (! getopts('d:fi', \%opts) ) {
    }
    $debug_val=$debug_val+$opts{d} if ( exists $opts{"d"} ) ; # -d debug mins
    
    my $source_path=$ARGV[0];
    my $dest_path=$ARGV[1];
    
    my @errors;
    if (scalar (@ARGV)!=2 ){
	push(@errors,"EXTRA ARGS! Did you put options in wrong place.");
    }
    if ( $#errors>=0 ) {
	print(join("\n",@errors)."\n");
	return 1;
    }
    print("source_path:\t$source_path\n");
    print("dest_path:\t$dest_path\n");
    my $files=discover_files($source_path);
    # makes hash of name=path,ext, can opeht with path+ext
    create_nhdr($files,$source_path,$dest_path,\%opts);
    return 0;
}


sub discover_files{
    my ($choice_pile)=@_;
    my $cmd="find  -E '$choice_pile' -iregex '.+nii(.gz)?|.+nhdr'";
    my $files={};
    print($cmd."\n");
    my @file_list=`$cmd`;
    chomp(@file_list);
    if( $#file_list<0 ){error_out("Could not list files at $choice_pile");}

    foreach my $file (@file_list){
	my ($p,$n,$e)=fileparts($file,2);
	# possibilities,
	# nii alone,
	# nhdr after nii
	# nii after nhdr

	# if we've already set
	if ( ! exists($files->{$n}) ) {
	    #print("New file $n: ");
	    $files->{$n}->{"path"}=$p.$n;
	    $files->{$n}->{"type"}=$e;
	}
	if( $e =~ /nhdr/ ) {
	    $files->{$n}->{"nhdr"}=1;
	    #print("has nhdr \n");
	} elsif (! exists($files->{$n}->{"nhdr"}) ){
	    #print ("Nii mode\n");
	    $files->{$n}->{"type"}=$e;
	}
    }
    return $files;
    #print("$s\n\n");
}

sub create_nhdr {
    my ($files,$source,$dest,$opts)=@_;
    if ($can_dump){
	#Data::Dump::dump($files);
    }
    for my $fn (keys %$files) {
	print("$fn: $files->{$fn}->{type}\n");
	my $input=$files->{$fn}->{"path"};
	
	my $output=$input;
	#$output=~ s/$source/$dest/; # this fails because metachars
	my $find=quotemeta($source);
	$output=~ s/$find/$dest/;
	#print("$source\n$dest\n");
	#print("$input\n$output\n"); exit;

	# put the extension back onto our input
	$input=$input.$files->{$fn}->{"type"};

	#
	# Backup input nhdr
	#
	# if its a nhdr existing.
	if( exists($files->{$fn}->{"nhdr"}) ) {
	    my $backup=$output.".bak.nhdr";
	    #$backup=~s/nhdr/bak.nhdr/x;
	    my $cmd="cp -p $input $backup ";
	    print($cmd."\n");
	    if( -f $backup ) { 
	    }
	    #qx/$cmd/;
	}
	my $outdata=$output.".raw.gz";
	$output=$output.".nhdr";

	#
	# get Abrev 
	#
	my ($p,$n)=fileparts($output,2);my $e=".nhdr";
	my $lc=get_conf($dest,$p);
	
	my $lib_name=$lc->get_value('LibName');
	#my $file_pat=$lib_conf->get_value('FilePattern');
	my $file_pat=$lc->get_value('FileAbrevPattern');
	my $file_ma=$lc->get_value('FileAbrevMatch');
	printd(30,"name=$n\npat=$file_pat\nmat=$file_ma\n");
	my @mc; my @ma=split('',$file_ma);
	for (@ma) {
	    if ($_ eq '\\' ){
		push(@mc,'$');
	    }else{
		push(@mc,$_);
	    }
	}
	$file_ma=join('',@mc);
	printd(30,"cleaned match to '$file_ma'\n");
	my $abrev=$n;
	#$abrev=~ s/^$file_pat$/$1/x;# this works.
	#$abrev=~ s/$file_pat/$1/gx;# this works.
	#$abrev=~ s/^$file_pat$/$1/gx;# this works.
	#$abrev=~ s/^$file_pat$/$file_ma/x;# this doesnt
	
	#($abrev)=$abrev=~ s/^$file_pat$/$file_ma/g; #this doent
	#($abrev)=$abrev=~ s/^$file_pat$/$file_ma/gx; # this doesnt
	#$abrev=~/$file_pat/;
	#eval ( "$abrev=$file_ma;") ;
	#eval ("$abrev=~ s/^$file_pat$/$file_ma/x");# this doesnt
	#$abrev=~ s/^$file_pat$/$file_ma/ee;# this does!!! This failed when we had beginning/ending sigls on the input pattern.
	#$abrev=~ s/$file_pat/$file_ma/ee;# this does!!!
	
	# use re 'debugcolor'; # useful debugging for regex
	# YAPE::Regex::Explain # alternative regex help, but didnt try it .
	$abrev=~ s/$file_pat/$file_ma/ee;# the ee is required!!!, BUT I DONT UNDERSTAND WHY!!!!
	#print("abrev=$abrev\n");
	
	#Data::Dump::dump(@stuff);exit;
	#printd(5,"${abrev}_1".lc($abrev)."\n");
	$abrev=lc( $abrev);# libconf
	if( $lc->get_value($abrev) !~ /NO_KEY/ ){
	    print("Switching abrev from $abrev to $lc->get_value($abrev)\n");
	    $abrev=$lc->get_value($abrev);
	}

	#
	# create output data.
	#
	my $slicer_app="/Applications/AtlasViewer20170316_Release.app/Contents/MacOS/atlasviewer";
	$slicer_app="/Applications/Slicer-4.7.0-2017-05-02.app/Contents/MacOS/Slicer";
        $slicer_app="/Volumes/james/Applications/Slicer-4.9.0-2018-07-12.app/Contents/MacOS/Slicer";
        
	if ( ! -f $slicer_app ) {
            die "This slicer code wont work without being mounted on a modern mac!\n MISSING:$slicer_app\n";
	    cluck("Slicer wasnt found where expected, trying a mounted panoramaHD");
	    $slicer_app="/Volumes/panoramaHD".$slicer_app;
	}
        
	my $cmd="$slicer_app --exit-after-startup --no-splash --no-main-window --python-script /Volumes/DataLibraries/_AppStreamSupport/DataHandlers/slicer_data_conv.py -i $input -o $output ";
	if ( exists($data_state->{$abrev}->{"bitdepth"} ) ){
	    $cmd=$cmd." --bitdepth ".$data_state->{$abrev}->{"bitdepth"};
	}
	printd(5,"$cmd\n");

	# when our output isnt there, OR
	# when out input is newer, OR
	# force bit is set.
	#  -- run the command...
	# (can replace with our "better" run_on_update
	my @cmd_out=();
	{
	    my @c_in=($input);
	    my @c_out=($outdata);
	    my $force=0;
	    if ( exists $opts->{"f"} ) {
		$force=1;
	    }
	    @cmd_out=run_on_update($cmd,\@c_in,\@c_out,$force,0);
	}

        #
	# add min/max to nhdr.
	#
        # Any min/max previously encoded is clobbered by passing through dirty old slicer code!!!!!
        # We check each possible source of a good min/max for the volume.
        # v_hr is an i/o hash setting what variables we'll read from the nhdr.
	my $v_hr={};
        # Check if we have an available canned min/max by abbreviation.
        # this'll be overridden by any libconf value, or nhdr value.
        if (! exists($data_state->{$abrev}->{"range"} ) ){
	    $lc->print_headfile();
	    printd(5,"Unknown abrev '$abrev' for file $input\n");
            $v_hr->{"min"}="test";
            $v_hr->{"max"}="test";
	} else {
            $v_hr->{"min"}=$data_state->{$abrev}->{"range"}[0];
            $v_hr->{"max"}=$data_state->{$abrev}->{"range"}[1];
        }
        # If the libconf mentions a min/max it is more reasonable than the guesses, so we'll use that.
        # this'll be overridden by any nhdr value.
        if( $lc->get_value("min") !~ /NO_KEY/ 
            && $lc->get_value("max") !~ /NO_KEY/ ){
            $v_hr->{"min"}=$lc->get_value("min");
            $v_hr->{"max"}=$lc->get_value("max");
        }
        # The most reliable info is an input nhdr.
        # If we're an nhdr/nrrd try to get our min/max fields,
        # failure will leave us without updated fields. 
        if ( $files->{$fn}->{"type"} =~ /[.]?(nrrd|nhdr)$/x ) {
	    $v_hr=read_nhdr_fields($input,$v_hr,':=');
        } 
        # now almost always ends up with encode min/max,
        # from either from abbrev guesses, the lib conf, or the source nrrd/nhdr.
        if ( $v_hr->{"min"} ne "test"
             && $v_hr->{"max"} ne "test" ) {
            print("Encoding min/max as found.");
            update_nhdr($output,$v_hr,':=');
        }

    }
}

sub get_conf {
    my ($source, $data_path)=@_;
    # given a source forest
    # find and load the confstack which will be in effect for data path ( a folder in which data is sitting).
    
    # current path,
    # 
    #
    # get abrev via lib.conf
    #
    use File::Spec;# mat not work as expected?
    #my $rel_path = 'myfile.txt';
    #my $abs_path = File::Spec->rel2abs( $rel_path ) ;
    #use Cwd;#may contain links, but thats ok.
    use Cwd 'abs_path';
    #my $dir = getcwd;
    #my $abs_path = abs_path($file);

    my @conf_stack;
    my $files={};
    #my $conf_path=$source."/lib.conf";
    #if ( ! -f $source."/lib.conf" ){
    printd(25,"Searching for lib.conf's in $source\n");
    # THIS CODE IS HOKEY AS HELL!
    # it gets Path from all libs in base directory, then resolves to correct path.
    # It looks for the exact path used.
    my $cmd="find  -E '$source' -iname 'lib.conf' ";
    my @file_list=`$cmd`;
    chomp(@file_list);
    if( $#file_list<0 ){error_out("Could find confs in $source");}
    @file_list=sort(@file_list);
    printd(40,"Conf search order:\n".join("\n",@file_list)."\n");
    # absolute data path.
    # which apparently we're not using.
    my $data_path_a;#= abs_path($data_path);
    ####$data_path_a=unrel_path($data_path);
    $data_path_a=$data_path;
    ####chomp($data_path_a);
    $data_path_a=~s:[\/]$::;# trim trailing slashes from path.
    $data_path_a =~ s/[^[:print:]]+//g;# remove non print chars from path
    printd(15,"Searching for '$data_path_a'\n");
    foreach my $file (@file_list){
	my @conf_lines=();
	my ($p,$n,$e)=fileparts($file,2);
	my $ap;# absolute_path
	load_file_to_array($file,\@conf_lines,$debug_val);
	#my @foo = grep(!/^#/, @bar);
	my @path_direct = grep(/^Path.*$/, @conf_lines);
        # this test_status check is a big bogus, because grep doesnt do full regex's.
        # normally, we only mention testinglib if we are one, so this should be fine.
	my @test_status = grep(/^TestingLib.*$/, @conf_lines);
        # if we need to check test_status better in the future, this regex should help.
        #	if ($test_bool =~ /^([Tt][Rr][Uu][Ee]|1)$/x ) {
	if (scalar(@test_status)>=1){
            printd(15,"Testing  conf $file, skipping to next\n");
	    next;}
	if (scalar(@path_direct)>=1){
	    if (scalar(@path_direct)>1){
		warn('mutltiple paths found, using last');
		sleep_with_countdown(3);
	    }
	    # when libraries load, they only use the last found value for a variable. so these lines do that.
	    $path_direct[$#path_direct]=~s/^Path=//;# this removes Path= from the line
	    $path_direct[$#path_direct]=~s:[\/]$::;# trim trailing slahes from path.
	    
	    my $rp=$p."/".$path_direct[$#path_direct];
	    $rp=~s:/+:/:gx; # convert repeating /'s into singles
	    
	    #$ap= abs_path($rp);
	    $ap = unrel_path($rp);# resolves ../ entries in path by removing that and eating the next part.
	    printd(25,"\tresolved path input:'$p' \n\t\trel:'$rp'\n\t\tabs:'$ap'\n");
	} else {
            printd(25,"\tdirect path used:'$p'\n");
	    $ap=$p;
            $ap=~s:[\/]$::;# trim trailing slahes from path.
	}
	$ap =~ s/[^[:print:]]+//g;
	if ( $ap eq $data_path_a ) {
	    unshift(@conf_stack,$file);
	    printd(15,"\tSucessfully found root lib.\n");
	    printd(15,"\t\tchecking $p/../lib.conf\n");
	    while( -f $p."/../lib.conf"){
		#$p=$p."/..";
		$p=~s:/+:/:gx;
		my @_t=split('/',$p);pop(@_t);$p=join('/',@_t);
		unshift(@conf_stack,$p."/lib.conf");
	    }
	    #exit;
	    last;
	}
    }
    #Data::Dump::dump(@file_list);exit;
    if(scalar(@conf_stack)<1 ){
	print("NO conf found for $data_path_a.\n");
	Data::Dump::dump(@file_list);exit;
    }

    #Data::Dump::dump(@conf_stack);
    #} else {
    #    printd(25,"Found $source conf\n");
    #}
    my $lc=new Headfile('nf');
    #Data::Dump::dump(@conf_stack);exit;
    
    for my $conf_path (@conf_stack){
	printd(20,"Loading $conf_path\n");
	my $lt=new Headfile('ro',$conf_path);
	if (! $lt->check() || ! $lt->read_headfile ) { confess( "Conf path failure $conf_path, \n\tfull_err:$!"); }
	
	my @keys=$lt->get_keys();
	foreach (@keys){
	    #if ( $lc->get_value($_) =~ /NO_KEY/ ) {
	    printd(45," Adding $_ to lib.conf\n");
	    $lc->set_value($_,$lt->get_value($_));
	    #} else {
	    #printd(45," $_ already in lib.conf\n");
	    #}
	}
    }
    my @keys=$lc->get_keys();
    if ( scalar(@keys) == 0 ) {
	confess("lib conf load failure");
    }
    #exit;
    return $lc;
}

sub unrel_path {
    my ($folder)=@_;
    
    my @o_f;
    my @_t=split('/',$folder);
    
    for my $nam (@_t) {
	if ($nam =~ /^[.]{2}$/x) {
	    pop(@o_f);
	} else {
	    push(@o_f,$nam);
	}
    }
    
    return join("/",@o_f);
}


sub read_nhdr_fields {
    my($hdr,$var_hash_ref,$sigil)=@_;
    # taking the $hdr path, and the variable hash ref.
    if (! defined $sigil){
	$sigil=':=';
    }
    my $var_hr = { %$var_hash_ref };# copy hash so we can destroy it 8) .
    my $err=1;
    my @lines;
    load_file_to_array($hdr,\@lines);
    chomp(@lines);
    
    my @vars=keys(%$var_hr);
    my $reg=join('|',@vars);
    my $line='';
    for $line(@lines) {
	if ( $line !~ /^$reg[^\w]+/ ){
	    # no match, not interested
	} else {
	    # existing, do update remove from hash
	    foreach ( @vars){ #check which var we found.
		if ( $line =~ /^$_[^\w]+/ ){
		    print("Found $_ line $line with value ");
		    #$line=~/^([^=]+).*/;
		    #$line=$1."=".$var_hr->{$_};
		    #$line=~/^[^=]+(.*)/; #includes the equals(doh)
		    $line=~/^($_[^\w])([^=])*=+(.*)$/;
		    print("$3\n");
		    $var_hr->{$_}=$3;
		    #delete $var_hr->{$_};
		}
	    }
	}
    }
    return $var_hr;
}

sub update_nhdr {
    my ($hdr,$var_hash_ref,$sigil)=@_;
    # taking the $hdr path, and the variable hash ref.
    if (! defined $sigil){
	$sigil=':=';
    }
    my $var_hr = { %$var_hash_ref };# copy hash so we can destroy it 8) .
    my $err=1;
    my @lines;
    load_file_to_array($hdr,\@lines);
    chomp(@lines);
    
    my @output;    
    my @vars=keys(%$var_hr);
    my $reg=join('|',@vars);
    my $line='';
    for $line(@lines) {
	if ( $line !~ /^$reg[^\w]+/ ){
	    push(@output,$line."\n");
	} else {
	    # existing, do update remove from hash
	    foreach ( @vars ) {
		if ( $line =~ /^$_[^\w]+/ ) {
		    print("Updating $_ line ($line) with ");
		    #$line=~/^([^=]+).*/;
		    #$line=$1."=".$var_hr->{$_};
		    $line=~/^($_[^\w])([^=])*=+(.*)$/;
		    $line=$_.$sigil.$var_hr->{$_};#$2."=" instad of sigil.
		    print("$_ -> ($line)\n");
		    push(@output,$line."\n");
		    delete $var_hr->{$_};
		}
	    }
	}
    }

    # any which didnt exist, add them now.
    foreach (keys(%$var_hr) ) {
	print("Adding $_ line ");
	$line=$_.$sigil.$var_hr->{$_};
	print("($line)\n");
	push(@output,$line."\n");
	
    }
    write_array_to_file($hdr,\@output);
    
    return $err;
}

1;
