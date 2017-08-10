#!/usr/bin/perl
# LibManager
# tranfers clean library to new location
# updates clean libraries
# verifies library contents.

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
use civm_simple_util qw(mod_time  sleep_with_countdown $debug_val $debug_locator);
$debug_val=20;



my $can_dump = eval {
    # this little snippit checks if the cool data structure dumping code is available.
    require Data::Dump;
    Data::Dump->import(qw(dump));
    1;
};

#copy definitions
#-rlptgoD
our %update_cmd = (
    'conf'=> 'rsync',
    'dir' => 'cp',
    'file'=> 'cp',
    'lib' => 'perl LibManager.pl',
    'rm'  => '/bin/rm',
    );
our %cmd_flags = (
    #'dir' => '-rpt --exclude="/* --delete"',
    'conf'=> '-pt --backup',
    'dir' => '-RPp',
    #'file'=> '-pt',
    'file'=> '-p',
    'lib' => '-d '.($debug_val+10),
    'rm'  => '-fr'
    );

# I keep reudicng template members in favor of coding the information into that individual lib.conf
# I think at this point only the three parts , DataTemplate_protocolmenu.qml, DataTemplate_Review.html, and lib.conf need remain.
# 
our %lib_template = (
#    'Atlases'                        => 'dir',
#    'About.qml'                      => 'file',
#    'blank.mrml'                     => 'file',
    'DataTemplate_protocolmenu.qml'  => 'file',
    'DataTemplate_Review.html'       => 'file',
    'lib.conf'                       => 'conf',
#    'models.mrml'                    => 'file',
#    'Static_Render'                  => 'lib',
    #'LabelModels'   '
    );

Main();

sub Main
{
    ### check_inputs its a hard generalization
    my %opts;
    if (! getopts('d:', \%opts) ) {
    }
    use List::Util qw[min max];
    if ( exists $opts{"d"} ) # -d debug mins
    {print "Seting debug max($debug_val,$opts{d})\n"; $debug_val=max($debug_val,$opts{d}); }
    my $source_path=$ARGV[0];
    my $dest_starter=$ARGV[1];

    my @errors;
    #    my @errors=check_inputs($source_path,$dest_starter,\%opts);
    if (scalar (@ARGV)!=2 ){
	push(@errors,"EXTRA ARGS! Did you put options in wrong place.");
    }
    if ( $#errors>=0 ) {
	print(join("\n",@errors)."\n");
	return;
    }

    # what are the steps to transfer and update libs?
    # figure out where in the path we want to do stuff.
    #  eg, how much of the path is symetric, once the path is symetric stop, run through the mkdir bits.
    # In plain language, parse dest_starter, and get last component dir.
    # Now we find that component in source, the components up to that point is the source_base, which is allowed to fluctuate.

    #my ($source_trail,$dest_base)=get_source_trail($source_path,$dest_starter);

    print("source_path:\t$source_path\n");
    print("dest_init:\t$dest_starter\n");
    my $dest_path=get_full_destpath($source_path,$dest_starter);
    if (-f $source_path ){
	my $fn;
	($fn,$source_path)=fileparse($source_path);
	($fn,  $dest_path)=fileparse($dest_path);
    }
    print("full_dest:\t$dest_path\n");
    if ( ! -d $source_path ) {
	confess( "Unavailable source: $source_path !");
    }

    my %dir_opts=('chmod' => 0777);
    if ( ! -d $dest_path ) {
	print("\tmkdir -p $dest_path\n");
	make_path($dest_path,\%dir_opts) if $debug_val<50;
    }
    #$dest_base/$source
    # we want mkdir $dest_base/$source_trail
    
    #my $failures = manage_lib($source_path,$dest_path);

    my $work=lib_parse($source_path,$dest_path);
    if ($can_dump){
	Data::Dump::dump($work);
    }
    my $failures=do_work($source_path,$dest_path,$work);
    if ($#{$failures} >= 0 ){
	print ("Fail manage:\n".join("\n",@{$failures})."\n");
    }
    #$dest_path/DataLibraries_mouse/000ExternalAtlasesBySpecies
    
    #execute comands. ?
    print("\tENDMAIN\n");
    return;
}

sub check_inputs
{
    my @messages=();
    
    if ( $#ARGV < 1 ) {
        push(@messages,"Not enough options specified, need in and out path.");
    } else {
	my ($path1,$path2,$opt_ref)=@_;
	my %opt_hash=%{$opt_ref};

	if ( ! defined $path1 || ! -d $path1 ) {
	    push(@messages, "problem nodir/notdir: $path1");
	}
	if ( ! defined $path1 || ! -d $path2 ) {
	    push(@messages, "problem nodir/notdir: $path2");
	}
    }
    return @messages;
}

# In plain language, parse dest_starter, and get last component dir.
# Now we find that component in source, the components up to that point are the source_base, which is allowed to fluxuate.
# 
sub get_full_destpath
{
    my ($source,$dest)=@_;
    my @s_parts=File::Spec->splitdir(path_collapse($source));
    my @d_parts=File::Spec->splitdir(path_collapse($dest));
    my @s_base=();
    my $ci=0;
    # while this part of source path, doesnt match the last element of dest parts
    while ($s_parts[$ci] !~ /$d_parts[$#d_parts]/x && $ci<=$#d_parts ) {
	push(@s_base,$s_parts[$ci]);
	$ci++;
    }
    my @eparts=@d_parts[0..$#d_parts-1];
    push(@eparts,@s_parts[$ci..$#s_parts]);
    
    #return path_collapse(File::Spec->catdir(@eparts));
    return File::Spec->catdir(@eparts);
}
=item 
    
    path_collapse(path)
    takes a path in and collapses any ../ elements in the middle of the path to their correct compenent.
    ex, /thing/thing2/../thinga = /thing/thinga
    ex2, /thing/thing2/thio/../../ = /thing

=cut
    
sub path_collapse 
{
    my($path)=@_;
    my @p_parts=File::Spec->splitdir($path);
    my @outpath;
    my $indent="";
    foreach (@p_parts) {
	if ($_ !~ /[.]{2}/ ) {#&& scalar(@outpath)>0 ){
	    print($indent."$_ (add) \n") if ($debug_val>40);
	    push(@outpath,$_);
	    $indent=$indent."  " if ($debug_val>40);
	} elsif(scalar(@outpath)==0 ){
	    die("NOT ENOUGH PATH PARTS");
	} else {
	    #	    $indent=~s/  //;
	    my $rem=pop(@outpath);
	    print($indent.$rem."(remove) \n") if ($debug_val>40);

	}
    }
    return File::Spec->catdir(@outpath);
}

sub dirbuild_lib
{
    # checks if lib has any work to do. makes a list of transfers if any are required.
    # builds directory tree if there is any.
    my @work=();
     
    return @work;
}

=item
    
    Given a libfolder path, 
    Check for a lib.conf file.
    +if it exists-> load the lib.conf file. Check for LibPath var.
    ++if it exists-> check modify time, if newer add lib.conf to work list and stop processing
    +-ifnot exists-> get proper libname, check libtemplate for available files, understand filepattern variable, add any files that match pattern, after the template files. Add any directories found. 

    -ifnot Exists-> return doing nothing
    

=cut
    
sub lib_parse
{
    my ($inpath,$outpath ) =@_;
    my $work_list={};
    my $conf_inpath=$inpath.'/'.'lib.conf';
    my $conf_outpath=$outpath.'/'.'lib.conf';
    if ( ! -f $conf_inpath) { # check inpath for a lib.conf.
	cluck( "No conf, not a lib");
    } else {
	#if ( ! -f $conf_outpath ){
	#}
	my $in_ts=mod_time($conf_inpath);
	my $out_ts=$in_ts-1; # because out doesnt have to exist, we'll make a dummy case of just one less
	if ( -e $conf_outpath){
	    $out_ts= mod_time($conf_outpath);
	}
	if ( $in_ts > $out_ts ) { # if its newer, we'll want to transfer that.
	    $work_list->{'lib.conf'}=$lib_template{'lib.conf'};
	}
	my $lib_conf=load_lib_conf($conf_inpath);
	my $lib_path=$lib_conf->get_value('Path');
	my $lib_name=$lib_conf->get_value('LibName');
	my $file_pat=$lib_conf->get_value('FilePattern');
	my $test_bool=$lib_conf->get_value('TestingLib');#=true
	if ($test_bool =~ /^([Tt][Rr][Uu][Ee]|1)$/x ) {
	    #confess( "TEST STATUS($test_bool) TRUE");
	    $test_bool=1;
	} else {
	    #confess( "TEST STATUS($test_bool) FALSE");
	    $test_bool=0;
	}
   	if ( $lib_path !~ /NO_KEY/x) { # eg Found a libpath, we're not a payload library
	    # index lib behavior! hopefully we'll handle this better by setting up a transfer for both the index lib, and the payload lib.
	    print("Redirect found \n");
    	    $work_list->{$lib_path}='lib';
	    #
	    # transfer lib into folder
	    #
	    # this is a bandaid becuase its not clear how to make this a standard part of work.
	    my $lib_conf_path="$inpath/$lib_path/lib.conf";
	    my $cmd="rsync -pt --backup $conf_inpath $lib_conf_path";
	    # print("Transfercmd:$cmd\n");exit;
	    qx($cmd);
	    # then run this sed on it.
	    $cmd='sed -i ".sed_bak" -e "s/^\(Path=.*\)$/#\1/g" '."$lib_conf_path >& 2"; # do the work
	    # print("pathcmd:$cmd\n");exit;
	    qx($cmd);
	    if ( $in_ts != $out_ts ) { # i just want not equal, because index's are special.
		$work_list->{'lib.conf'}=$lib_template{'lib.conf'};
	    }
	} else {
	    $lib_path=$inpath;
	    #http://stackoverflow.com/questions/35241844/how-to-the-access-the-last-item-of-a-list-returned-by-a-subroutine-without-copyi
	    # getting the last path component via answer from weblink.
	    # exact code before using my vars " my ($last) = ( range() )[-1]; "
	    if ( $lib_name =~ /NO_KEY/x) {
		#print("No custon LibName\n");
		($lib_name) = ( File::Spec->splitdir($lib_path) )[-1];
	    }
	    if ( $file_pat =~ /NO_KEY/x) {
		#print("Universal match!\n");
		$file_pat = ".+"; 
	    }
	    
	    #my %cur_template=%lib_template;#duplicate template.
	    my @template_entries=();
	    # get keys of lib template
	    # replace DataTemplate with $lib_name for any keys in which it exists.
	    foreach (keys %lib_template) {
		$_ =~ s/DataTemplate/$lib_name/gx;
		push(@template_entries,$_);
	    }
	    $file_pat='(^'.$file_pat.'$)|(^'.join('$)|(^',@template_entries).')$';
	    print("Complete File pattern: $file_pat\n");
=item
	    opendir(my $dh, $some_dir) || confess( "Can't open $some_dir: $!");
	    while (readdir $dh) {
		print "$some_dir/$_\n";


	    }
	    closedir $dh;
=cut
	    
	    opendir(my $dhout, $outpath) || confess( "Can't open $outpath: $!");
	    while (readdir $dhout) {
		if ( $_ =~ /^[.]{1,2}$/){ # if its a . or .. skip. Actually i want to skip any hidden files i think.
		#if ( $_ =~ /^[.].*$/){ # If we're a hidden file (eg starting with .) .
		    #print ("skip $_\n");
		    next;
		}
		my $f_inpath=$inpath.'/'.$_;
		my $f_outpath=$outpath.'/'.$_;
		if ( ! -e $f_inpath ) {
		    print("Remove(no input) $_\n");
		    $work_list->{$_}='rm';
		} elsif ( $_ =~ /.*junk.*/x
			  || $_ =~ /.*~/x ) {
		    print("Remove(junk) $_\n");
		    $work_list->{$_}='rm';
		} elsif ( $_ !~ /$file_pat/x ) {
		    print("Remove(nomatch) $_\n");
		    $work_list->{$_}='rm';
		} elsif ( $test_bool ) {
		    print("Remove(testlib) $_\n");
		    $work_list->{$_}='rm';
		} elsif ( $_ =~ /^[.]([^.]+|[.].+)$/){ 
		    # starts with . and has more than one additional non . char or starts with .. and has additional chars
		    print("Remove(hidden) $_\n");
		    $work_list->{$_}='rm';
		}
	    } 
	    closedir $dhout;

	    opendir(my $dhin, $inpath) || confess( "Can't open $inpath: $!");
	    while (readdir $dhin) {
		#if ( $_ =~ /^[.]{1,2}$/ || $test_bool ){ # if its a . or .. skip.
		if ( $_ =~ /^[.].*$/ || $test_bool ){ #  If we're a hidden file/folder (eg starting with .) .
		    print("Ignore(hidden) $_\n");
		    next;
		} elsif ( $_ =~ /$file_pat/x 
			  && $_ !~ /.*junk.*/x
			  && $_ !~ /.+~/x ) {
		    my $f_inpath=$inpath.'/'.$_;
		    my $f_outpath=$outpath.'/'.$_;
		    
		    $in_ts=mod_time($f_inpath);#intime
		    $out_ts=$in_ts-100; # because out doesnt have to exist, we'll make a dummy case of just one less
		    if ( -e $f_outpath){
			$out_ts= mod_time($f_outpath) ;
		    }
		    if ( $in_ts > $out_ts || -d $f_inpath  ) { # if its newer, we'll want to transfer that. #
			#$f_inpath =~ s:[ ]:[\][ ]:gx;# add \ to any space in names. but why...
			if ( -f $f_inpath){
			    $work_list->{$_}='file';
			} elsif( -d $f_inpath) {
			    if ( -f $f_inpath.'/lib.conf' ) {
				$work_list->{$_}='lib';
			    } else {
				$work_list->{$_.'/'}='dir';
			    }
			}
			if (exists $lib_template{$_}) {
			    #print("Override type\n");
			    $work_list->{$_}=$lib_template{$_};
			}
			if ( defined $work_list->{$_} ) {
			    print("Add $f_inpath <- ".$work_list->{$_}."\n");
			} else {
			    cluck ("work_list $_ not defined!"); }
		    } else {
			print("Ignore(time) $_\n");
		    }
		} elsif ( $_ =~ /.*junk.*/x
			  || $_ =~ /.*~/x ) {
		    print("Ignore(junk) $_\n");
		} else {
		    print("Ignore(nomatch) $_\n");
		}
	    }
	    closedir $dhin;
	}
    }
    
    return $work_list;
}


sub load_lib_conf
{
    my ($conf_path)=@_;
    my $lc=new Headfile('ro',$conf_path);
    if (! $lc->check() || ! $lc->read_headfile ) { confess( "Conf path failure $conf_path, \n\tfull_err:$!"); }
    return $lc;
}

sub do_work
{
    my ($inpath,$outpath,$work)=@_;
    my @fail_paths=();

    foreach (keys %$work ){
	my $cp_flags=$cmd_flags{$work->{$_}}; # work vall will be either dir|file
	my ($cmd,$in_ts,$out_ts,$in_p,$out_p);
	$out_p=$outpath."/$_";

	## if not rm
	if ( $work->{$_} !~ /rm/ ){
	    $in_p=$inpath."/$_";
	    confess("IN_P:$in_p missing!") if ( ! -e $in_p );
	    $in_ts=mod_time("$in_p");
	    $in_p="\'".$inpath."/$_"."\'";
	    $out_ts=$in_ts-1;
	} else {
	    # rm mode, no inpath. no in time.
	    $in_p="";
	    $out_ts=mod_time("$out_p");
	    $in_ts=$out_ts-1;
	}
	
	if ( $work->{$_} =~ /conf/ ) {
	    my $suf="";
	    if ( -f "$out_p" ){
		$out_ts=mod_time("$out_p");
		my $dt = DateTime->from_epoch(epoch => $out_ts);
		$suf=".".$dt->ymd;
	    }
	    $cp_flags=$cp_flags." --suffix=$suf.bak"
	}
	my $outp="\'".$out_p."\'";# adding single quotes to out_p here, but using normal out_p for rest of function.
	#if ( $work->{$_} =~/lib/){
	    #print("\t$update_cmd{$work->{$_}} $cp_flags $in_p $outp\n");
	#}
	$cmd= "$update_cmd{$work->{$_}} $cp_flags $in_p $outp";
#	if ($work->{$_} =~ /rm/ ) {
#	    $cmd= "$update_cmd{$work->{$_}} $cp_flags $out_p";
#	}

	my $fail_cond=0;

	###
	# open and readline print with tab at front.
	###
	# replaces simple backtik call: UNTESTED.
	#`$cmd`;
	#	/Volumes/c$-1
	if($debug_val>=50 ) {
	    print("Debugging over 50, $debug_val\n");
	    $cmd="echo ".$cmd;
	}
	my $pid = open( my $CID,"-|", "$cmd"  ) ;
	
	print("PID:$pid\n") if $debug_val>=45;
	while ( my $line=<$CID> ) {
	    $line =~ s/\s+$//;
	    print("\t".$line."\n");
	}
	if ( $work->{$_} =~ /rm/ ) {
	    if ( -e "$out_p") {
		print("Remaining file error:\n\t$cmd\n -e $out_p\n");
		$fail_cond++;
	    }
	} else {
	    if ( ! -e "$out_p" ) {
		print("Unwritten file error:\n\t$cmd\n ! -e $out_p\n");
		$fail_cond++;
	    } else {
		$out_ts=mod_time("$out_p");
		if ( $in_ts != $out_ts && ! -d "$out_p" ) {
		    # should this be a not -d as in, if file, not dir?
		    # eg, ! -d , or -f 
		    print("Time error:\n\t$in_ts\n\t$out_ts\n");
		    $fail_cond++;
		}
	    }
	}
	if ( $fail_cond>0){
	    push(@fail_paths,"# $work->{$_} - $out_p");
	}
	
    }
    return \@fail_paths;
}

sub manage_lib
{
    my ($source_path,$dest_path)=@_;
    my $work=lib_parse($source_path,$dest_path);
    return do_work($source_path,$dest_path,$work);
    
}
1;

=item simple lib example
    
    >dirtree DataTemplate_simple
    |-
    |-/About.qml
    |-/blank.mrml
    |-/DataTemplate_protocolmenu.qml
    |-/DataTemplate_Review.html
    |-/lib.conf
    |-/models.mrml
    |-/Static_Render
    |---LabelModels

=cut
    
1;
=item complex lib example

    >dirtree DataTemplate_complex
    |-
    |-/000Index
    |---blank.mrml
    |---DataTemplate_protocolmenu.qml
    |---DataTemplate_Review.html
    |---lib.conf
    |---01Entry
    |-----lib.conf
    |---02Member
    |-----lib.conf
    |---03Name
    |-----lib.conf
    |-/DataTree
    |---Entry
    |-----About.qml
    |-----models.mrml
    |-----Static_Render
    |-------LabelModels
    |---Member
    |-----About.qml
    |-----models.mrml
    |-----Static_Render
    |-------LabelModels
    |---Name
    |-----About.qml
    |-----models.mrml
    |-----Static_Render
    |-------LabelModels
=cut
    
1;
