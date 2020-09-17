#!/usr/bin/perl
#


use strict ;
use Getopt::Std ;
use Geo::KML ;
use Data::Dumper ;
use XML::LibXML ;
use Math::Polygon ;
use KMZ ;
use cvxPolygon;

$Data::Dumper::Indent = 1;
my $milesperlat = 69 ;
my $milesperlong = 54.6 ; 

our $opt_f = "" ;
our $df = "kml.dat" ;
my $odf = "kmlmod.dat" ;
our $opt_k = "" ;
getopts('f:k:') ;
my @colors = (0xffff0000, 0xff00ff00, 0xff0000ff, 0xffaa3333, 0xff33aa22,0xff00cccc, 0xff22cc22, 0xff22aacc) ;
my %pmlistentry ;

if ($opt_f eq "") {
	die "Usage: kmz.pl -f <input file> [-c to cluster] [-k <output kml file>]\n" ;
}
else {
	open(F1,$opt_f) || die "Can't open file $opt_f\n" ; 
	if ($opt_k eq "") {
		($opt_f =~ m@.*([A-Z]{2}).kmz@) && 
			do {
				$opt_k = $1 . "mod.kmz" ; 
				print "output kmz file=$opt_k\n"; 
			} ;
	}
}

srand($$) ;


#my ($ns,$data) = Geo::KML->from($opt_f) ;
my ($ns,$data) = Geo::KML->readKML($opt_f) ;
# print the top level entries of the hash
my $dhash = %$data{'Document'} ;
for (keys %$dhash) {
	print "Key $_: Value $$dhash{$_}\n" ;
}
my $featuregroup = $$dhash{'AbstractFeatureGroup'} ;
my $stylegroup = $$dhash{'AbstractStyleSelectorGroup'} ;

close(F2) ;
#print "Writing to kmz file $opt_k\n" ;
#my $opkml = Geo::KML->new(version => '2.2.0') ;
#$opkml->writeKML($data,$opt_k) ;

#defined $ns or die "don't understand file content\n";
#print "$ns\n" ;

#my $dom = XML::LibXML->load_xml(string => $data);
#foreach my $title ($dom->findnodes('coordinates')) {
#    say $title->to_literal();
#}
#
#
my $EPS = 0.001 ;
my $totalArea = 0 ;
my $aoiCtr=0;
my $cxavg = 0 ;
my $cyavg = 0 ;
my @placemarkhashes;
my $placemarks = 0;
my @featureref ;
my $featurecnt = 0 ;
foreach my $fg (@$featuregroup) {
	for my $fkey (keys %$fg) {
		print "Key $fkey: Value $$fg{$fkey}\n" ;
		next unless ($fkey eq 'Folder') ;
		my $fder = %$fg{$fkey} ;
		for my $fderkey (keys %$fder) {
			print "Folder Key $fderkey: Value $$fder{$fderkey}\n" ;
			next unless ($fderkey eq 'AbstractFeatureGroup') ;
			$featureref[$featurecnt]  = $$fder{'AbstractFeatureGroup'} ;
			foreach my $fcount (@{$featureref[$featurecnt]})
			{
				for my $fcntkey (keys %$fcount) {
					#					print "Feature Key $fcntkey: Value $$fcount{$fcntkey}\n" ;
					if ($fcntkey eq 'Placemark') { 
						%pmlistentry = %$fcount ; 
						push @placemarkhashes,$$fcount{$fcntkey} ; $placemarks++; 
					}
				}
			}
			$featurecnt++ ;
		}
		
	}
}
print "$placemarks Placemarks found, $featurecnt Features found\n" ;

use Math::Polygon::Convex qw/chainHull_2D/ ;

my @counties ;
my %countydata ;
foreach my $pref (@placemarkhashes) {
	my $countyAoiCtr = 0;
	my $geometries = $$pref{'MultiGeometry'}{'AbstractGeometryGroup'} ;
	my $description = $$pref{'description'} ;
	my ($county,$new) = getCounty($description,\@counties) ;
	if ($new == 0) {
		push @counties, $county;
		my @listofAois ;
		my @cx ;
		my @cy ;
		my @data ;
		my $aoiCtr = 0;
		$data[0] = \@listofAois ;
		$data[1] = \@cx ;
		$data[2] = \@cy ;
		$data[3] = \$aoiCtr ;
		$countydata{$county} = \@data ;
	}
	my @pcoords ;
	my @polygonlist ;
	my $nxtp=0;

	my $listofAois = ${$countydata{$county}}[0] ;
	my $cx = ${$countydata{$county}}[1] ;
	my $cy = ${$countydata{$county}}[2] ;
	my $countyAoiCtr = ${$countydata{$county}}[3] ;
	foreach my $geomkey (@$geometries) {
		my $coordinates = $$geomkey{'Polygon'}{'outerBoundaryIs'}{'LinearRing'}{'coordinates'} ;
		my @plist = arrayToPolygon($coordinates) ;
		splice @pcoords,@pcoords,0,@plist ;
		$polygonlist[$nxtp++] = Math::Polygon->new(@plist) ;

		undef $$geomkey{'Polygon'}{'altitudeMode'} ;
	#{ print "coordinate string: $$geomkey{'Polygon'}{'outerBoundaryIs'}{'LinearRing'}{'coordinates'}\n" ; }
	}
		my $nxtaoi = chainHull_2D @pcoords ;
	#	my $nxtaoi = Math::Polygon->new(cvxPolygon::combinePolygonsConvex(\@polygonlist)) ;
	$nxtaoi->beautify() ;
	my $pcnt = $nxtaoi->nrPoints ;
	my $parea = $nxtaoi->area()*$milesperlat*$milesperlong ;
	#	printf "Converted placemark to convex hull of %d points, area = %.4g (closed=%d) ", $pcnt,$parea,$nxtaoi->isClosed() ;
	next unless ($parea > $EPS) ;
	next unless ($nxtaoi->isClosed()) ;
	my $center =  $nxtaoi->centroid() ;
	($$cx[$$countyAoiCtr],$$cy[$$countyAoiCtr]) = @$center ;
	#print " centroid=$$cx[$$countyAoiCtr],$$cy[$$countyAoiCtr]\n" ; 
	my %aoihash = ( 'name' => $$pref{'name'} , 'polygon' => \$nxtaoi ) ;
	push @$listofAois,\%aoihash ;
	$totalArea += $parea ;
	$$countyAoiCtr++ ;
	$aoiCtr++ ;
}
print "$aoiCtr AOIs recorded, total area of $totalArea: " ;
for my $cname (keys %countydata) {
	my $pc = ${$countydata{$cname}}[0] ;
	my $np = @$pc ;
	print "$cname -> $np ",
}
print "\n" ;


my (@clusters,@clustercenters,$numclusters,@tclusters,$nc) ;
$nc = $numclusters = 0;
foreach my $cn (keys %countydata)
{
	print "Trying K-means clustering for $cn \n" ;
	($clusters[$nc],$clustercenters[$nc],$tclusters[$nc]) = aoiClusters(${$countydata{$cn}}[0],${$countydata{$cn}}[1],${$countydata{$cn}}[2],$totalArea) ;
	$numclusters += $tclusters[$nc] ;
	print "$tclusters[$nc] clusters returned (total=$numclusters)\n" ;
	$nc++ ;
}
my $nc = 0;
my $clr ;
foreach my $stylehash (@$stylegroup) {
	for (keys %$stylehash) {
		print "Key $_: Value $$stylehash{$_}\n" ;
		my $st = $$stylehash{'Style'} ;
		my $ps = $$st{'PolyStyle'} ;
		$clr = $$ps{'color'} ;
		printf "Current colour = %x\n" , $clr ;
	}
	$nc++;
}
print "Found $nc styles\n" ;
my $oldnc = $nc ;
$nc = 0;
for ($nc = 0; $nc<@colors; $nc++){
	print "Adding new style $nc\n" ;
	my %newstyle ;
	my %newst = makeNewStyle($nc,$colors[$nc]) ;
	$newstyle{'Style'} = \%newst ;
	push @$stylegroup, \%newstyle ;
}

my $newcn = $oldnc ;
#foreach my $cluster_id (sort keys %{$clusters}) {
#		$nc++ ;
	#	print "\n$cluster_id   =>   @{$clusters->{$cluster_id}}\n";

my @newclusters ;
my $i = 0;
foreach my $cn (keys %countydata)
{
foreach my $newc (keys %{$clusters[$i]}) {
	my @clusterpoints ;
	my @clist = @{$clusters[$i]->{$newc}} ;
	my @plist ;
	print "newc = $newc newcn = $newcn\n" ;
	for my $pk (@clist){
		my $pgon = 0 ;
		my $preflist = ${$countydata{$cn}}[0];
		foreach my $pref (@$preflist) {
			if ($$pref{'name'} eq $pk) {
				$pgon = $$pref{'polygon'} ;
				last ;
			}
		}
		if ($pgon == 0) {
			die "Couldn't find $pk in data for $counties[$i]\n" ;
		}
		#		if ($pgon == 0) {die "Can't find $pk in list of placemarks\n" ;}
		my @points = $$pgon->points() ;
		splice @clusterpoints,@clusterpoints,0,@points ;
		push @plist,$$pgon ;
	}
	#	my $clusterpoly = chainHull_2D @clusterpoints ;
	my $clusterpoly = Math::Polygon->new(cvxPolygon::combinePolygonsConvex(\@plist)) ;
	#	printf "Convex operation returns polygon with %d points, closed=%d\n",$clusterpoly->nrPoints(),$clusterpoly->isClosed() ;
	my %options ;
	$options{'remove_spike'} = 1 ;
	$clusterpoly->beautify(%options) ;
	@clusterpoints = $clusterpoly->points() ;
	
	my $description = makeNewDescription("Cluster $newcn, county $cn") ;
	my $cstyle = sprintf("ClusterStyle%.3d",$newcn%@colors) ;
	my $newcluster = makeNewCluster($clusterpoly,\%pmlistentry,$newcn,$cstyle,$description) ;
	$newclusters[$newcn - $oldnc] = $newcluster ;
	$newcn++ ; printf("newcn -> $newcn\n") ;
}
$i++ ;
}
#Assign styles to placemarks
#foreach my $pref (@placemarkhashes) {
#	my $styleid = findInClusters($$pref{'name'},$clusters) ;
#	next unless ($styleid != -1) ;
#
#}
#	$$pref{'styleUrl'} = '#PolyStyle' . sprintf("%.3d",$styleid%$nc) ;
#		print "Changing style to $$pref{'styleUrl'}\n" ;
	
splice @{$featureref[0]},@{$featureref[0]},0,@newclusters ;

my $opkml = Geo::KML->new(version => '2.2.0') ;
if ($opt_k =~ /.*[.]kmz$/) {
	print "Writing to kmz file $opt_k\n" ;
	$opkml->writeKML($data,$opt_k,1) ;
}
elsif ($opt_k =~ /.*[.]kml$/) {
	print "Writing to kml file $opt_k\n" ;
	$opkml->writeKML($data,$opt_k) ;
}
else {
	print "Don't understand file type $opt_k\n" ;
}
exit(1) ;


use Algorithm::KMeans ;
sub aoiClusters{
	my $aoisref = shift ;
	my $cxref = shift ;
	my $cyref = shift ;
	my $tA = shift ;
	my $nc = 0;
	my $datafile = "aoi" . $$ . ".csv" ;
	my $kmin = int($tA/2000) ;
	my $kmax = int(sqrt(@$aoisref/2)) ;
	print "Initial estimate kmax=$kmax kmin=$kmin\n" ; 
	if (@$aoisref < 9) {
		my @list ;
		my @center = ($$cxref[0],$$cyref[0]) ;
		for (my $i = 0 ; $i <@$aoisref; $i++) {
			push @list, ${$$aoisref[$i]}{'name'} ;
		}
		my %sc ;
		$sc{'cluster0'} = \@list;
		return (\%sc, \@center,1) ;
	}


	while ($kmax <= $kmin && $kmin > 4) {
		$kmin -= $kmin << 2;
	}
	if ($kmax <= $kmin) {
		$kmax = 12 ; $kmin = 6 ;
	}

		$kmax = $kmin = int(sqrt(@$aoisref/2)) ;
	open (FTMP, ">",$datafile) || die "Can't open $datafile for creating cluster list\n" ;
	for (my $aoi=0 ; $aoi < @$aoisref; $aoi++) {
		printf FTMP "%s,%.6g,%.6g\n", ${$$aoisref[$aoi]}{'name'}, $$cxref[$aoi], $$cyref[$aoi] ;
	}
	close (FTMP) ;
	print "Trying K-means with $kmax,$kmin clusters\n" ;
	my $clusterer = Algorithm::KMeans->new(
		datafile        => $datafile,
                mask            => "N11",
                K               => 0,
		Kmin		=> $kmin,
		Kmax		=> $kmax,
                cluster_seeding => 'random',   
                use_mahalanobis_metric => 0,  
                terminal_output => 0,
                write_clusters_to_files => 0 ) ;
	$clusterer->read_data_from_file() ;
	my ($clusters,$clusterCenters) = $clusterer->kmeans() ;
	foreach my $cluster_id (sort keys %{$clusters}) {
		$nc++ ;
		print "\n$cluster_id   =>   @{$clusters->{$cluster_id}}\n";
	}
	unlink($datafile) ;
	printf "Generated %d clusters\n",$nc;
	return ($clusters,$clusterCenters,$nc) ;
	
}

sub findInClusters {
	my $name = shift ;
	my $clusters = shift ;
	foreach my $cid (keys %{$clusters})
	{
		for my $centry (@{$clusters->{$cid}}) {
			if ($centry eq $name) {
				#				print "Matched $name to $cid\n" ;
				my $tok ;
				($cid =~ /cluster(\d+)/) && do { $tok = $1 ; } ;
				return $tok ;
			}
		}
	}
	return -1;
}


sub arrayToPolygon{
	my $cref = shift ;
	my @coords = @$cref ;
	my @plist ;
	my $cntr = @coords ;
	my $nxt = 0 ;
	
	#	printf "Array to Polygon: array of size %d\n",($#coords+1) ;
	for (my $i = 0; $i <= $#coords; $i++) {
		my @xy ;
		my ($x,$y,$z) = split(/,/,$coords[$i]) ;
		$xy[0] = $x ;
		$xy[1] = $y ;
		@plist[$nxt++] = \@xy ;
	}
	@plist ;
}



sub getCounty{
	my $dstr = shift ;
	my $clist = shift ;
	my $cname = "" ;
	my $fnd = 0 ;
	if ($dstr =~ m@<td>county</td>\s*<td>([A-Za-z]+)</td>@s) {
		$cname = $1 ;
		for my $ce (@$clist) {
			if ($ce eq $cname) {
				$fnd = 1 ;
				last ;
			}
		}
		return ($cname,$fnd) ;
	}
	return ($cname,$fnd) ;
}
	

