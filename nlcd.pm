#!/usr/bin/perl
package nlcd;

require Exporter ;
use Data::Dumper ;
$Data::Dumper::Indent = 1;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(codePointList);

my $tDir = "/home/ggne0015/src/hnsNetPlan/HNSNetworkPlanning/updated_auction_904_kml/srtm/NLCD_2016" ;
sub codePointList {
	my $pts = shift ;
	my $codes = shift ;
	my %bilfiles ;
	foreach my $pt (@$pts) {
		my $lat = $$pt[0] ;
		my $long = $$pt[1] ;
		my ($fname,$dname) = constructFileDirName($lat,$long) ;
		if (not defined $bilfiles{$fname}) {
			my %bfContainer ; 
			if (!fileInit($fname,$dname,\%bfContainer)) {
				push @$codes,9999;
				next ;
			}
			#foreach my $bfckey (keys %bfContainer) {
			#	print "$bfckey => $bfContainer{$bfckey}\n" ;
			#}
			$bilfiles{$fname} = \%bfContainer ;
		}
		my $nlcdData = readNLCDData($bilfiles{$fname},$lat,$long) ;
		print "$lat,$long ==> $nlcdData\n" ;
		push @$codes,$nlcdData ;
	}
}

#
# File name NLCD2016_N33W96 contains:
# y: 36 to 33
# x: -96 to -93 
#
sub constructFileDirName {
	my $lat = shift ;
	my $long = shift ;
	my ($bdx,$bdy) ;
	#print "Longitude: $long, Latitude:$lat\n" ;
	die unless $long < 0 && $lat > 0 ;
	$bdx = int($long/3) ; $bdy = int($lat/3) ;  
	$bdx = -3*($bdx-1) ; $bdy = 3*int($bdy) ;
	my $fname = sprintf( "NLCD2016_N%2dW%2d" , $bdy,$bdx) ;
	my $dname = sprintf( "NLCD2016_N%2dW%2d" , $bdy,$bdx) ;
	#print "Directory $dname File $fname\n" ;
	return ($fname,$dname) ;
}

sub fileInit {
	my $fname = shift ;
	my $dname = shift ;
	my $fileCont = shift ;
	my ($fhdrname,$fbilname) ;
	print "Init $fname\n" ;
	$fhdrname = $tDir . "/" . $dname . "/" . $fname . ".hdr" ;
	$fbilname = $tDir . "/" . $dname . "/" . $fname . ".bil" ;
	unless (-e $fhdrname) { print "Couldn't find $fhdrname\n" ; return 0 ; }
	unless (-e $fbilname) { print "Couldn't find $fbilname\n" ; return 0 ; } 
	open (FH, $fhdrname) || die "Can't open $fhdrname for reading:$!\n" ;
	while (<FH>) {
		my @keyv = split(/\s+/) ;
		print "$keyv[0] => $keyv[1]\n" ;
		$$fileCont{$keyv[0]} = $keyv[1] ; 
	}
	close (FH) ;
	my $fbil ;
	open ($fbil, $fbilname) || die "Can't open $fbilname for reading:$!\n" ;
	binmode $fbil ;
	$$fileCont{'fh'} = \$fbil ;
	return 1 ;
}

#
# File name NLCD2016_N33W96 contains:
# y: 36 to 33, decreasing
# x: -96 to -93 , increasing
# ulxmap: -96
# ulymap: 36
#
sub readNLCDData {
	my $fileContainer = shift ;
	my $lat = shift ;
	my $long = shift;
	my $xoffset = int(($long - $$fileContainer{'ULXMAP'})/($$fileContainer{'XDIM'})) ;
	my $yoffset = int(($$fileContainer{'ULYMAP'} - $lat)/($$fileContainer{'YDIM'})) ;
	print "$xoffset,$yoffset for $lat,$long\n" ;
	my $offset = $yoffset*$$fileContainer{'TOTALROWBYTES'} ;
	my ($raw,$alt,$dh) ;
	$dh = ${$$fileContainer{'fh'}} ;
	seek $dh,$offset,0 ;
	my $success = read $dh, $raw, 1 ;
	die "Couldn't read binary file:$!\n" unless defined $success ;
	return ord($raw) ;
}
