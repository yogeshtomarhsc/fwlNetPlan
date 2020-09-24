#!/usr/bin/perl
#
#

use strict ;
use Data::Dumper ;
use nlcd ;
use Getopt::Std ;

our ($opt_b,$opt_n);
$opt_n = 100 ;
getopts('b:n:') ;

my ($bboxnorth,$bboxsouth,$bboxwest,$bboxeast) ;
if ($opt_b =~ /([0-9.]+),*([-0-9.]+)::([0-9.]+),*([-0-9.]+)/) {
	$bboxnorth = ($1 > $3? $1:$3) ;
	$bboxsouth = ($1 < $3? $1:$3) ;
	$bboxwest = ($2 > $4? $4:$2) ;
	$bboxeast = ($2 < $4? $4:$2) ;
	print "Bounding box: $bboxnorth:$bboxwest(NW) to $bboxsouth:$bboxeast (SE) \n" ;
}
else {
	die "Usage: $0 -b <bounding box> [-n points]\n" ;
}

srand($$) ;
my @codes ;
my @points ;
for (my $cnt = 0; $cnt < $opt_n ; $cnt++) {
	my @position = (35.455,-95.4533) ;
	my $affine = rand(1) ;
	$position[0] = $bboxnorth*$affine + $bboxsouth*(1 - $affine) ;
	$affine = rand(1) ;
	$position[1] = $bboxwest*$affine + $bboxeast*(1 - $affine) ;
	push @points, \@position ;
}
nlcd::codePointList(\@points,\@codes) ;

#
# Histogram
#
my %histogram ;
for (my $cv = 0; $cv < @codes; $cv++) {
	next if ($codes[$cv] == 9999)  ;
	my $keyv = sprintf("%2d",$codes[$cv]) ;
	if (not defined %histogram{$keyv}) {
		$histogram{$keyv} = 0 ;
	}
	$histogram{$keyv}++ ;
}
foreach my $histval (keys %histogram) {
	print "$histval => $histogram{$histval}\n" ;
}

