#!/usr/bin/perl
#Libraary updater
exit;
use strict;
use warnings;
use File::Stat;

# for a given base folder,
# find all of its contents and update from server

my $source_dir="/Volumes/DataLibraries";
my $template_dir="/Users/BiGDATADUMP/LibrariesInTheCloud/";
my $base_path=$ARGV[0];
print "Base path $base_path";
if ( ! -z "$ARGV[1]" );
{
    print "Source_path $2";
    $source_dir=$2;
}
if ( ! -z "$ARGV[2]" )
{
    $template_dir=$ARGV[2];
}

my $b_createmode=0;
my $fpath=$base_path;
if ( -d $base_path ) {

}
elsif(-d $template_dir ) 
{
    #create mode.
    $b_createmode=1;
    my $fpath=$tempate_dir;
    #  lets lndir the files/folders???
}

#update mode
my $cmd="find $fpath -mtime +$test_age -type f -printf \"%TY-%Tm-%Td-%Tw_%TT|%T@|%AY-%Am-%Ad-%Aw_%AT|%A@|%s|%u|%h/%f\n\" ";
my $pid = open( my $CID,"-|", "$cmd"  ) ;
print("PID:$pid\n");
my $files_found=0;
while ( my $line=<$CID> ) {
    $files_found++;
    chomp $line;
    my ($timestamp,$mod_epoc,$accesstime,$access_epoc,$bytesize,$user,$file,@rest)=split('\|',$line);
    if ( $file !~ /junk/x ) {
	my $src_file=$file;
	if ( $b_createmode ){
	    $src_file =~ s|$base_path|$source_dir|x;
	    if ( -e "$src_file" ) {
		fi
		
	    }
	} else {
	    $src_file =~ s|$base_path|$source_dir|x;
	    if ( -e "$src_file" ) {
		my $newer=0;
		$newer=1 if stat($src_file)->mtime > $timestamp;
		if ( "$file" -ot "$src_file" || $override) 
		{
		    print "#$file is older than $src_file" ;
		    print "cp -p $src_file $file";
		    `cp -fp $src_file $file`;
		}
		else
		{
		    print "  #no copy! $file";
		}
	    }
	    else
	    {
		print "  #no file! $src_file";
		print "cp -p $file $src_file";
	    }
	}
    }
    else
    {
	print "    #junk! $file";
    }
}
close $CID;
    


#print "#diff -qrx \"*~\" $base_path $source_dir" #|grep -v \"~"
#diff -qrx "*~" $base_path $source_dir

