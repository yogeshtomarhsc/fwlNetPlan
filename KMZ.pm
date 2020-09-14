#!/usr/bin/perl
package KMZ;

require Exporter ;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(makeNewStyle makeNewCluster makeNewPolygon);


sub polygonToArray {
	my $plist = shift ;
	my @pts = @$plist ;
	my @opstr ;
	foreach my $i (@pts) {
		my $pstr ;
		my @xy = @$i ;
		last if (@xy == 0) ;
		$pstr = sprintf "%.10g,%.10g,0", $xy[0], $xy[1] ;
		push @opstr,$pstr ;
	}
	@opstr ;
}
sub makeNewStyle{
	my %newst ;
	my $num = shift ;
	my $styleid = "ClusterStyle" . sprintf("%.3d",$num) ;
	my ($red,$blue,$green) ;
	$red = int(rand(255)) ;
	$blue = int(rand(255)) ;
	$green = int(rand(255)) ;
	my $clr = (0xff<<24) | (($blue) << 16) | (($green) << 8) | ($red)  ;
	$newst{'id'} = $styleid ;
	$newst{'PolyStyle'} = {'color' => $clr, 'outline' => 1, 'fill' => 0} ;
	$newst{'LabelStyle'} = { 'color' => $clr, 'scale' => 0.0000 } ;
	$newst{'LineStyle'} = { 'color' => $clr, 'width' => 3.0000 } ;
	%newst ;
}
sub makeNewCluster{
	my $clusterpoly = shift ;
	my $template = shift ;
	my $newcn = shift ;
	my %newcluster ;
	my $polygoncoords  = makeNewPolygon($clusterpoly) ;
	my %placemark ;
	my %polygon ;
	my @polygons ;
	$placemark{'name'} = sprintf "Cluster_%d",$newcn ;
	$placemark{'styleUrl'} = sprintf ("ClusterStyle%.3d",$newcn) ;
	$placemark{'description'} = "Empty string"; 
	$placemark{'id'} = sprintf("ClusterID_%d",$newcn)  ;

	$polygon{'outerBoundaryIs'}{'LinearRing'}{'coordinates'} = $polygoncoords ;
	$polygon{'extrude'} = 0 ;
	my %geom;
	$geom{'Polygon'} = \%polygon ;
	push @polygons,\%geom ;

	$placemark{'MultiGeometry'}{'AbstractGeometryGroup'} = \@polygons ;
	$newcluster{'Placemark'} = \%placemark ;
	return \%newcluster ;
}

sub makeNewPolygon{
	my $polygon = shift ;
	my @absgrouplists ; 
	my $plist = $polygon->points() ;
	my @pcoords = polygonToArray($plist) ;
	#	my %phashref ;
	#$phashref{'outerBoundaryIs'}{'LinearRing'}{'coordinates'} = \@pcoords ;
	#$phashref{'altitudeMode'} = 'clampToGround' ;
	#$phashref{'extrude'} = 0;
	#%phashref ;
	return \@pcoords ;
}
