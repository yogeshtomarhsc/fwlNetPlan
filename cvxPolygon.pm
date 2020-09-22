#!/usr/bin/perl
package cvxPolygon;

require Exporter ;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(combinePolygonsConvex printPointList);
#
# Start processing.. combine all points into single array 
#
sub combinePolygonsConvex{
	my $polylist = shift ;
	my @points ;
	my $nump = @$polylist;
	printf "Processing %d polygons\n", $nump ;
	foreach my $p (@$polylist)
	{
		my @ppoints = $p->points() ;
		splice @ppoints,@ppoints-1,1 ;
		splice (@points,@points,0,@ppoints) ;
	}
	
	my $ptcnt = @points;
	print "Starting with $ptcnt points  " ;
	my @outsidepoints ;
	$ptcnt=0;
	for my $pt (@points) {
		my ($x,$y) ;
		$x = $$pt[0] ;
		$y = $$pt[1] ;
		my $skip=0 ;
		for (my $i = 0; $i<@$polylist; $i++) {
			if ($$polylist[$i]->contains($pt) && 
				($$polylist[$i]->distance($pt) != 0) &&
		       		notAlreadyIn(@outsidepoints,$pt)) 
				{ $skip = 1 ; last ; }
		}
		if ($skip == 0) { $outsidepoints[$ptcnt++] = $pt ; }
	}
	print " reduced to $ptcnt\n" ; 
	#	printPointList(\@outsidepoints,"After consolidation",0) ;
	#
	#Normalize the points
	#
	my ($centx,$centy) ;
	$centx = $centy =0 ;
	for my $j (@outsidepoints) { $centx += $$j[0] ; $centy += $$j[1] ; }
	$centx /= $ptcnt ; $centy /= $ptcnt;
	#print "Centroid = $centx, $centy\n" ;
	for (my $j=0; $j<@outsidepoints; $j++) {
		my $pt = $outsidepoints[$j] ; 
		${$pt}[0] -= $centx ;${$pt}[1] -= $centy;
	}
	
	#
	# Sort points so that we are in clock wise order
	# and restore the centroid
	#
	my @sortedpoints = sort cmpClockwise @outsidepoints;
	
	for (my $j=0; $j<@sortedpoints; $j++) {
		my $pt = $sortedpoints[$j] ;
		${$pt}[0] += $centx ;${$pt}[1] += $centy;
	}
	makeClosed(\@sortedpoints) ;
	#printPointList(\@sortedpoints,"After sorting",0) ;
	
	#Test for convexity
	my $cvx = 1 ;
	do {  
		$cvx = makeConvexPolygon(\@sortedpoints) ;
	} while ($cvx != 0) ;
	#printPointList(\@sortedpoints,"After convexing",0) ;
	makeClosed(\@sortedpoints) ;
	return @sortedpoints;
}
use Math::Trig;
sub cmpClockwise{
	#	my $a = shift ;
	#my $b = shift ;
	my ($xa,$ya,$xb,$yb) ;
	$xa = $$a[0] ; $xb = $$b[0] ;
	$ya = $$a[1] ; $yb = $$b[1] ;
	my ($ta,$tb) ;
	if ($ya == 0) { $ta = 0 } else { $ta = atan2($xa,$ya) ; }
	if ($yb == 0) { $tb = 0 } else { $tb = atan2($xb,$yb) ; }
	#	printf "Comparing %.4g,%.4g (%.4g), to %.4g,%.4g (%.4g)\n", $xa,$ya,$ta,$xb,$yb,$tb ;
	if ($ta > $tb) { return 1 ; }
	elsif ($ta < $tb) { return -1 ; }
	else { return 0 ; }
}
sub notAlreadyIn{
	my @plist = shift ;
	my $pt = shift ;
	my ($x,$y) = ($$pt[0],$$pt[1]) ;
	foreach my $p (@plist) {
		if ($x == $$p[0] &&
			$y == $$p[1] ) {
			return 0 ;
		}
	}
	return 1 ;
}

sub makeConvexPolygon {
	my $pts = shift ;
	my @skip ;
	my $cvx = 0 ;
	for (my $i = 0; $i < @$pts; $i++) {
		my $pt0 = $$pts[$i] ;
		my $pt1 = $$pts[($i+1)%@$pts] ;
		my $pt2 = $$pts[($i+2)%@$pts] ;
		my $dx1 = $$pt1[0] - $$pt0[0];
		my $dy1 = $$pt1[1] - $$pt0[1];
		my $dx2 = $$pt2[0] - $$pt1[0];
		my $dy2 = $$pt2[1] - $$pt1[1];
		my $zcrossproduct =  ($dx1*$dy2 - $dy1*$dx2) ;
		if ($zcrossproduct > 0) {
			$skip[($i+1)%@$pts] = 1 ;
			#			print "$$pt1[0],$$pt1[1] is non-convex\n" ;
			$cvx++ ;
		}
		else
		{
			$skip[($i+1)%@$pts] = 0 ;
		}
	}
	for (my $i = @$pts-1; $i >= 0; $i--) {
		if ($skip[$i] == 1 ) {
			#print "Overwriting $i\n" ;
			for (my $j = $i; $j < @$pts-1; $j++) {
				$$pts[$j] = $$pts[$j+1] ;
			}
		}
	}
	splice @$pts,@$pts-$cvx,$cvx ;
	#	printPointList($pts,"inside convex",0) ;
	return $cvx ;
}

sub makeClosed {
	my $polygon = shift;
	if ( (${$$polygon[@$polygon - 1]}[0] != ${$$polygon[0]}[0]) ||
	     (${$$polygon[@$polygon - 1]}[1] != ${$$polygon[0]}[1])){
		my @newlastpoint ;
		$newlastpoint[0] = ${$$polygon[0]}[0]; 
		$newlastpoint[1] = ${$$polygon[0]}[1]; 
		push @$polygon,\@newlastpoint ;
	}
}

sub printPointList {
	my $plist = shift ;
	my $string = shift ;
	my $verbose = shift ;
	my $np = @$plist ;
	print "$string number of points=$np\n" ;
	for (my $j=0; $j<@$plist; $j++) {
		last unless ($verbose)  ;
		printf "[%.4g:%.4g] ",${$$plist[$j]}[0], ${$$plist[$j]}[1] ;
	}
	printf("\n") ;
}
