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
use civm_simple_util qw(printd mod_time  sleep_with_countdown load_file_to_array write_array_to_file $debug_val $debug_locator);
$debug_val=20;


my $can_dump = eval {
    # this little snippit checks if the cool data structure dumping code is available.
    require Data::Dump;
    Data::Dump->import(qw(dump));
    1;
};

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
#$data_state->{"adc"}->     {"range"}=[0.0, 0.001]; #good for chass
$data_state->{"b0"}->      {"range"}=[ 1500,20000];
$data_state->{"chi"}->     {"range"}=[-0.20,0.20];
$data_state->{"dwi"}->     {"range"}=[ 1500,20000];
$data_state->{"fa"}->      {"range"}=[  0.0, 0.7];
$data_state->{"fa_color"}->{"range"}=[    0,170];
$data_state->{"gre"}->     {"range"}=[ 1500,20000];
$data_state->{"labels"}->  {"range"}=[    0,255];
#$data_state->{"md"}->      {"range"}=[    0, 0.001]; # but we're not useing MD! AND we canonically call md adc.
$data_state->{"t2star"}->  {"range"}=[ 1500,20000];
$data_state->{"rd"}->      {"range"}=[ 0.0, 0.001];




Main();
exit;

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
	return;
    }
    print("source_path:\t$source_path\n");
    print("dest_path:\t$dest_path\n");
    my $files=discover_files($source_path);
    # makes hash of name=path,ext, can opeht with path+ext
    create_nhdr($files,$source_path,$dest_path,\%opts);
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
	my $find=quotemeta($source);
	#$output=~ s/$source/$dest/; # this fails because metachars
	$output=~ s/$find/$dest/;
	#print("$source\n$dest\n");
	#print("$input\n$output\n"); exit;
	$input=$input.$files->{$fn}->{"type"};


	#
	# Backup input nhdr
	#
	# if not existing.
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
	$abrev=~ s/$file_pat/$file_ma/ee;# this does!!!
	#print("abrev=$abrev\n");
	
	#Data::Dump::dump(@stuff);exit;
	$abrev=lc( $abrev);
	if( $lc->get_value($abrev) !~ /NO_KEY/ ){
	    print("Switching abrev from $abrev to $lc->get_value($abrev)\n");
	    $abrev=$lc->get_value($abrev);
	}

	#
	# create output data.
	#
	
	my $slicer_app="/Applications/AtlasViewer20170316_Release.app/Contents/MacOS/atlasviewer";
	$slicer_app="/Applications/Slicer-4.7.0-2017-05-02.app/Contents/MacOS/Slicer";
	my $cmd="$slicer_app --exit-after-startup --no-splash --no-main-window --python-script /Volumes/DataLibraries/_AppStreamLibraries/DataHandlers/slicer_data_conv.py -i $input -o $output ";
	if ( exists($data_state->{$abrev}->{"bitdepth"} ) ){
	    $cmd=$cmd." --bitdepth ".$data_state->{$abrev}->{"bitdepth"};
	}
	printd(5,"$cmd\n");
	if ( ! -f $outdata || exists $opts->{"f"} 
	     || -M $outdata > -M $input ) {
	    if ( -M $output > -M $input ) {
		print("Time update for $input -> $output\n");
	    } elsif ( -M $outdata > -M $input ) {
		print("Time update for $input -> $outdata\n");
	    }
	    #print("make nhdr $input $output\n");
	    qx/$cmd/; # make new file
	    
	} else {
	    printd(30,"data exists for $output\n");
	}

	if (! exists($data_state->{$abrev}->{"range"} ) ){
	    $lc->print_headfile();
	    #Data::Dump::dump($lc);exit;
    	    confess ("Unknown abrev '$abrev'\n");
	}
	
	#
	# add min/max to nhdr.
	#
	
	#$cmd="if [ `grep -c 'min:=' $output` -eq 0 ]; then echo 'min:=$data_ranges{$abrev}[0]' >> $output ; fi";
	#print($cmd."\n");qx/$cmd/;
	#$cmd="if [ `grep -c 'max:=' $output` -eq 0 ]; then echo 'max:=$data_ranges{$abrev}[1]' >> $output ; fi";
	#print($cmd."\n");qx/$cmd/;

	my $v_hr={} ;
	$v_hr->{"min"}=$data_state->{$abrev}->{"range"}[0];
	$v_hr->{"max"}=$data_state->{$abrev}->{"range"}[1];
	update_nhdr($output,$v_hr,':=');
	#last;
    }
}

sub get_conf {
    my ($source, $data_path)=@_;
    # starting source, there should will be aconf, 1-2 levels deep.
    
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
    my $cmd="find  -E '$source' -iname 'lib.conf' ";
    my @file_list=`$cmd`;
    chomp(@file_list);
    if( $#file_list<0 ){error_out("Could find confs $source");}
    @file_list=sort(@file_list);
    printd(40,"Conf search order:\n".join("\n",@file_list)."\n");
    my $data_path_a= abs_path($data_path);
    #$data_path_a=unrel_path($data_path);
    $data_path_a=$data_path;
    #chomp($data_path_a);
    $data_path_a=~s:[\/]$::;# trim trailing slashes from path.
    $data_path_a =~ s/[^[:print:]]+//g;# remove non print chars from path
    printd(15,"Searching for '$data_path_a'\n");
    foreach my $file (@file_list){
	my @conf_lines=();
	my ($p,$n,$e)=fileparts($file,2);
	my $ap;
	load_file_to_array($file,\@conf_lines,$debug_val);
	#my @foo = grep(!/^#/, @bar);
	my @path_direct = grep(/^Path.*$/, @conf_lines);
	my @test_status = grep(/^TestingLib.*$/, @conf_lines);
	if (scalar(@test_status)>=1){
	    next;}
	if (scalar(@path_direct)>=1){
	    if (scalar(@path_direct)>1){
		warn('mutltiple paths found, using last');
		sleep_with_countdown(3);
	    }
	    # when libraryies load, they only use the last found value for a variable. so these lines do that.
	    $path_direct[$#path_direct]=~s/^Path=//;# this removes Path= from the line
	    $path_direct[$#path_direct]=~s:[\/]$::;# trim trailing slahes from path.
	    
	    my $rp=$p."/".$path_direct[$#path_direct];
	    $rp=~s:/+:/:gx;
	    
	    #$ap= abs_path($rp);
	    $ap = unrel_path($rp);
	    printd(25,"resolved path input:'$p' \n\trel:'$rp'\n\tabs:'$ap'\n");
	} else {
	    $ap=$p;
	}
	$ap =~ s/[^[:print:]]+//g;
	if ( $ap eq $data_path_a ) {
	    unshift(@conf_stack,$file);
	    printd(15,"Sucessfully found root lib.\n");
	    printd(15,"\tchecking $p/../lib.conf\n");
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
    #Data::Dump::dump(@conf_stack);
    #} else {
    #    printd(25,"Found $source conf\n");
    #}
    my $lc=new Headfile('nf');
    for my $conf_path (@conf_stack){
	printd(30,"Loading $conf_path\n");
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

sub update_nhdr {
    my ($hdr,$var_hash_ref,$sigil)=@_;
    if (! defined $sigil){
	$sigil=':=';
    }
    my $var_hr = { %$var_hash_ref };# copy hash so we can destroy it 8) .
    # taking the $hdr path, and the variable hash ref.
    my $err=1;
    my @lines;
    my @output;
    load_file_to_array($hdr,\@lines);
    chomp(@lines);
    my @vars=keys(%$var_hr);
    my $reg=join('|',@vars);
    my $line='';
    for $line(@lines) {
	if ( $line !~ /^$reg[^\w]+/ ){
	    push(@output,$line."\n");
	} else {
	    # existing, do update
	    foreach ( @vars){
		if ( $line =~ /^$_[^\w]+/ ){
		    print("Updating $_ line $line with ");
		    $line=~/^([^=]+).*/;
		    $line=$1."=".$var_hr->{$_};
		    print("$line\n");
		    push(@output,$line."\n");
		    delete $var_hr->{$_};
		}
	    }
	}
    }
    
    foreach (keys(%$var_hr) ) {
	print("Updating $_ line with ");
	$line=$_.$sigil.$var_hr->{$_};
	print("$line\n");
	push(@output,$line."\n");
	
    }
    write_array_to_file($hdr,\@output);
    
    return $err;
}

1;
