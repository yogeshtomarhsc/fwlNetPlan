#!/usr/bin/perl
package KMZ;

require Exporter ;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(makeNewOutlineStyle makeNewSolidStyle makeNewCluster makeNewPolygon makeNewDescription makeNewFolder);


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
sub makeNewOutlineStyle{
	my %newst ;
	my $num = shift ;
	my $rgb = shift || -1;
	my $styleid = shift || "ClusterStyle" . sprintf("%.3d", $num) ;
	my ($red,$blue,$green) ;
	if ($rgb == -1) {
		$red = int(rand(255)) ;
		$green = int(rand(255)) ;
		$blue = int(rand(255)) ;
	}
	else {
		$red = ($rgb>>16) & 0xFF ;
		$green = ($rgb>>8) & 0xFF ;
		$blue = ($rgb) & 0xFF ;
	}
	my $clr = (0xff<<24) | (($blue) << 16) | (($green) << 8) | ($red)  ;
	$newst{'id'} = $styleid ;
	$newst{'PolyStyle'} = {'color' => $clr, 'outline' => 1, 'fill' => 0} ;
	$newst{'LabelStyle'} = { 'color' => $clr, 'scale' => 0.0000 } ;
	$newst{'LineStyle'} = { 'color' => $clr, 'width' => 3.0000 } ;
	%newst ;
}
sub makeNewSolidStyle{
	my %newst ;
	my $num = shift ;
	my $rgb = shift || -1;
	my $styleid = shift || "TerrainStyle" . sprintf("%.3d", $num) ;
	my ($red,$blue,$green) ;
	if ($rgb == -1) {
		$red = int(rand(255)) ;
		$green = int(rand(255)) ;
		$blue = int(rand(255)) ;
	}
	else {
		$red = ($rgb>>16) & 0xFF ;
		$green = ($rgb>>8) & 0xFF ;
		$blue = ($rgb) & 0xFF ;
	}
	my $clr = (0xff<<24) | (($blue) << 16) | (($green) << 8) | ($red)  ;
	$newst{'id'} = $styleid ;
	$newst{'PolyStyle'} = {'color' => $clr, 'outline' => 1, 'fill' => 1} ;
	$newst{'LabelStyle'} = { 'color' => $clr, 'scale' => 0.0000 } ;
	$newst{'LineStyle'} = { 'color' => $clr, 'width' => 0.1000 } ;
	%newst ;
}
sub makeNewCluster{
	my $county = shift ;
	my $clusterpoly = shift ;
	my $template = shift ;
	my $newcn = shift ;
	my $styleid = shift || sprintf("ClusterStyle%.3d",$newcn) ;
	my $desc = shift || "Empty string\n" ;
	my %newcluster ;
	my $polygoncoords  = makeNewPolygon($clusterpoly) ;
	my %placemark ;
	my %polygon ;
	my @polygons ;
	$placemark{'name'} = sprintf "%s/Cluster_%d",$county,$newcn ;
	$placemark{'styleUrl'} = "#".$styleid ;
	$placemark{'description'} = $desc; 
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

sub makeNewDescription{
	my $details = shift ;
	if ($details eq "") { $details = sprintf("No Details provided") ; }
my $descstring = sprintf <<EODESC
'<html xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:msxsl="urn:schemas-microsoft-com:xslt">
<head>
<META http-equiv="Content-Type" content="text/html">
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>

<body style="margin:0px 0px 0px 0px;overflow:auto;background:#FFFFFF;">
<table style="font-family:Arial,Verdana,Times;font-size:12px;text-align:left;width:100%;border-collapse:collapse;padding:3px 3px 3px 3px">
<tr style="text-align:center;font-weight:bold;background:#9CBCE2">
<td>$details</td>

</tr>
</body>

</html>
EODESC
;
return $descstring ;
}

my $fdrcount = 1 ;
sub makeNewFolder {
	my $name = shift ;
	my $listofplacemarks = shift;
	my $folder = shift; ;
	$name =~ tr/\s+// ;
	$$folder{'name'} = $name ;
	my $num = @$listofplacemarks ;
	print "Making folder $name with $num placemarks\n" ;
	$$folder{'AbstractFeatureGroup'} = $listofplacemarks ;
        $$folder{ 'id'} = sprintf("FeatureLayer%d",$fdrcount) ; $fdrcount++ ;
        $$folder{'description'} = $name ;
	my %snippet ;
	$snippet{'_'} = '' ;
	$snippet{'maxLines'} = 2 ;
	$$folder{'Snippet'} = \%snippet ;
}
