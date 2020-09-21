#!/usr/bin/perl
#

use strict;
use Getopt::Std;
use Math::Polygon;
use Chart::Plot ;
use proximityCluster ;
use Data::Dumper ;
$Data::Dumper::Indent = 1;

my $img = Chart::Plot->new() ;
our ($opt_p,$opt_s,$opt_P) ;
$opt_p = 14 ;
$opt_P = 8 ;
$opt_s = $$ ;
getopts('p:s:P:') ;
print "Using seed:$opt_s\n" ;
srand($opt_s) ;
my @colors = ('red','green','blue') ;
#
# Make boxes. Each box has an id, a centroid and a 

my @boxes ;
for (my $i = 0; $i < $opt_P; $i++) {

	my %box ;
	$box{'id'} = sprintf("bbox:%.3d", $i) ;
	my @centroid ;
	$centroid[0] = rand(20) ;
	$centroid[1] = rand(20) ;
	my $poly = makeNewClosedPolygon($opt_p,@centroid) ;
	my $cnt = $poly->centroid ;
	$box{'centroid'} = $cnt ;
	$box{'area'} = $poly->area ;
	printf "Polygon of centroid %.4g,%.4g, area %.4g\n",
		$$cnt[0], $$cnt[1],
		$poly->area ;
	push @boxes,\%box ;
	my @thesepoints = $poly->points();
	my (@xvals,@yvals) ;
	splitArray(\@thesepoints,\@xvals,\@yvals) ;
	$img->setData(\@xvals,\@yvals, $colors[$i%3]) || die $img->error();
}
my $nb = @boxes ;
printf "Produced array of size $nb boxes\n" ;
my %clusters = proximityCluster::proximityCluster(\@boxes,1.25) ;
foreach my $cluster_id (sort keys %clusters) {
		print "\n$cluster_id   =>   @{$clusters{$cluster_id}}\n";
}

#$img->setData(\@xcvals,\@ycvals,'blue') || die $img->error() ;
open(WR,">img.png") || die "Can't open img.png\n" ;
print WR $img->draw("png") ;
close(WR) ;

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

sub makeNewClosedPolygon {
	my $pts = shift;
	my @centroid = shift ;
	my @points ;
	for (my $i = 0; $i<$pts; $i++) {
			my $xy = makeRandomPoint($i/$pts,@centroid) ;
		my @xyv = @$xy;
		#printf "Point=%.4g %.4g\n", $xyv[0], $xyv[1] ;
		$points[$i] = $xy ;
	}
	my @lastpoint = @{$points[0]} ;
	push @points, \@lastpoint ;
	my $poly = Math::Polygon->new(@points) ;
printf "Created a polygon with %d points\n", $poly->nrPoints() ;
	return $poly ;
}

sub makeRandomPoint{
	my $angle = shift;
	my @centroid ;
       $angle = $angle * (355.0*2.0)/114.0 ;
	my @pt ;
	my $val = 20.0*rand() ;
	$pt[0] = int($val*cos($angle)+20.0) + $centroid[0] ;
	$pt[1] = int($val*sin($angle)+20.0) + $centroid[1] ;
	return \@pt;
}
