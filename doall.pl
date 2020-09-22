#!/usr/bin/perl
#

use strict;
use Getopt::Std;


our ($opt_d,$opt_D,$opt_h) ;
$opt_d = "." ;
$opt_D = "processed/" ;
getopt('d:D:h') ;
if ($opt_h) {
	die <<EOH
	Usage: doall.pl -d <directory to read kmz files from> -D <directory to write processed files to>
EOH
;
exit(1) ;
}
opendir(DIR, $opt_d) || die "Can't open directory $opt_d:$!\n" ;

while (my $fname = readdir(DIR)) {
	print "Executing $fname\n" ;
	next unless ($fname =~ m@^([A-Z]+).kmz$@);
	my $ofile = $opt_D . $1."mod.kmz" ;
	my $rfile = $opt_D . $1."report.csv" ;
	my $tfile = $opt_D . $1."terrain.csv" ;
	#print "Executing $fname...$ofile\n" ;
	my $estring = "./kmz.pl -f ". $opt_d . $fname . " -k " . $ofile . " -r " . $rfile . " -K proximity7.5";
	$estring .= " -t $tfile" ;
	print "$estring\n" ;
	#	system($estring) ;
}
