#!/usr/bin/perl
#

use strict;
use Getopt::Std;


our ($opt_d,$opt_D,$opt_h) ;
$opt_d = "." ;
$opt_D = "processed/" ;
our $opt_w = "" ;
getopt('d:D:hw:') ;
if ($opt_h) {
	die <<EOH
	Usage: doall.pl -d <directory to read kmz files from> -D <directory to write processed files to> [-w <whitelist csv file>
EOH
;
exit(1) ;
}
opendir(DIR, $opt_d) || die "Can't open directory $opt_d:$!\n" ;

while (my $fname = readdir(DIR)) {
	next unless ($fname =~ m@^([A-Z]+).kmz$@);
	print "Executing $fname\n" ;
	my $state = $1 ;
	my $ofile = $opt_D . $1."mod.kmz" ;
	my $rfile = $opt_D . $1."report.csv" ;
	my $tfile = $opt_D . $1."terrain.csv" ;
	my $wfile ;
	if ($opt_w eq "") { $wfile = $opt_d . "CBG_Short_List_v1.csv" ; }
	elsif (-e $opt_w) { $wfile = $opt_w ; }
	else { die "Provided whitelist file $opt_w doesn't exist\n" ; }

	#print "Executing $fname...$ofile\n" ;
	my $estring = "./kmz.pl -f ". $opt_d . $fname . " -k " . $ofile . " -r " . $rfile . " -K proximity3";
	$estring .= " -w " . $wfile . " 2>&1 |";
	#$estring .= " -t $tfile |" ;
	print "$estring\n" ;
	#	system($estring) ;
		open (SH, "$estring") || die "Can't open $estring\n" ;
	while (<SH>) {
		chomp ;
		if (/Couldn't find/) { print "$_\n" ; }
	#	/State.*xmin=([-0-9.]+).*xmax=([-0-9.]+).*ymin=([-0-9.]+).*ymax=([-0-9.]+)/ &&
	#		do {
	#			if ($opt_b) { print FH "$state,$1,$2,$3,$4\n" ;  }
	#			{ print "$state,$1,$2,$3,$4\n" ;  }
	#		} ;
	}
	close(SH) ;
}
close (FH) ;
