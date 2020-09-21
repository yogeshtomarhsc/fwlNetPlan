#!/usr/bin/perl
#

use strict;
use Getopt::Std;
use Math::Polygon;
use Math::Polygon::Convex qw/chainHull_2D/ ;
use Chart::Plot ;
use cvxPolygon ;

sub sortClockwise ;
my $img = Chart::Plot->new() ;
our ($opt_p,$opt_P,$opt_s) ;
$opt_p = 14 ;
$opt_P = 2 ;
$opt_s = 778 ;
getopts('p:P:s:') ;
print "$opt_P polygons, $opt_p points in each polygon\n" ;
my @poly ;
srand($opt_s) ;
for (my $i = 0; $i < $opt_P; $i++) {
	$poly[$i] = makeNewClosedPolygon($opt_p) ;
	my @thesepoints = $poly[$i]->points() ;
	my (@xvals,@yvals) ;
	splitArray(\@thesepoints,\@xvals,\@yvals) ;
	$img->setData(\@xvals,\@yvals, 'red noline') || die $img->error();
}

my $np = @poly ;
print "Processed $np polygons\n" ;
my @sortedpoints = cvxPolygon::combinePolygonsConvex(\@poly) ;
my (@xcvals, @ycvals) ;
splitArray(\@sortedpoints,\@xcvals,\@ycvals) ;
$img->setData(\@xcvals,\@ycvals,'blue') || die $img->error() ;
open(WR,">img.png") || die "Can't open img.png\n" ;
print WR $img->draw("png") ;
close(WR) ;

sub makeNewClosedPolygon {
	my $pts = shift;
	my @points ;
	for (my $i = 0; $i<$pts; $i++) {
			my $xy = makeRandomPoint($i/$pts) ;
			#my $xy = makeSpecificPoint($i) ;
		my @xyv = @$xy;
		printf "Point=%.4g %.4g\n", $xyv[0], $xyv[1] ;
		$points[$i] = $xy ;
	}
	my @lastpoint = @{$points[0]} ;
	push @points, \@lastpoint ;
	my $poly = Math::Polygon->new(@points) ;
printf "Created a polygon with %d points\n", $poly->nrPoints() ;
	return $poly ;
}

sub splitArray{
	my $dual = shift ;
	my $xa = shift ;
	my $ya = shift ;
	my (@d) = @$dual ;
	my $i ;
	for ($i = 0; $i<@d; $i++) {
		my @dv = @{$d[$i]} ;
		${$xa}[$i] = int($dv[0]) ;
		${$ya}[$i] = int($dv[1]) ;
		printf "[%d %d],", ${$xa}[$i], ${$ya}[$i] ;
	}
	print "\n" ;
}


sub makeSpecificPoint{
	my $pt = shift ;
	my @xy;
	if ($pt == 0) { $xy[0] = 1 ; $xy[1] = 1 ; }
	elsif ($pt == 1) { $xy[0] = 0 ; $xy[1] = 0.5 ; }
	elsif ($pt == 2) { $xy[0] = -1 ; $xy[1] = 1 ; }
	elsif ($pt == 3) { $xy[0] = -1 ; $xy[1] = -1 ; }
	elsif ($pt == 4) { $xy[0] = 1 ; $xy[1] = -1 ; }
	return \@xy ;
}

sub makeRandomPoint{
	my $angle = shift;
       $angle = $angle * (355.0*2.0)/114.0 ;
	my @pt ;
	my $val = 20.0*rand() ;
	$pt[0] = int($val*cos($angle)+20.0) ;
	$pt[1] = int($val*sin($angle)+20.0) ;
	return \@pt;
}
