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
our $opt_r = "sampleReport.csv" ;
getopts('f:k:r:') ;
my @colors = (0xffff0000, 0xff00ff00, 0xff0000ff, 0xffaa3333, 0xff33aa22,0xff00cccc, 0xff22cc22, 0xff22aacc) ;
my @browncolors = (0xfffff8dc, 0xffffe4c4, 0xfff5deb3, 0xffd2b48c, 0xff8c8f8f,0xfff4a460, 0xffdaa520, 0xa0522d) ;
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
if ($opt_r) {
	printf "Dumping report to %s\n",$opt_r ;
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
my %terrainData ;
foreach my $pref (@placemarkhashes) {
	my $countyAoiCtr = 0;
	my $geometries = $$pref{'MultiGeometry'}{'AbstractGeometryGroup'} ;
	my $description = $$pref{'description'} ;
	my ($county,$new) = getCounty($description,\@counties) ;
	#if ($new == 0) {
	if (!defined %countydata{$county}) {
		push @counties, $county;
		my @listAois ;
		my @cx ;
		my @cy ;
		my @clusters ;
		my %data ;
		my $aoiCtr = 0;
		$data{'aois'} = \@listAois ;
		$data{'cx'}= \@cx ;
		$data{'cy'} = \@cy ;
		$data{'centroid'} = \$aoiCtr ;
		$data{'clusters'} = \@clusters ; 
		$countydata{$county} = \%data ;
	}
	my @pcoords ;
	my @polygonlist ;
	my $nxtp=0;

	my $listofAois = $countydata{$county}{'aois'} ;
	my $cx = $countydata{$county}{'cx'} ;
	my $cy = $countydata{$county}{'cy'} ;
	my $countyAoiCtr = $countydata{$county}{'centroid'};
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
	$nxtaoi->simplify() ;
	my $pcnt = $nxtaoi->nrPoints ;
	my $parea = $nxtaoi->area()*$milesperlat*$milesperlong ;
	#	printf "Converted placemark to convex hull of %d points, area = %.4g (closed=%d) ", $pcnt,$parea,$nxtaoi->isClosed() ;
	next unless ($parea > $EPS) ;
	next unless ($nxtaoi->isClosed()) ;
	my $center =  $nxtaoi->centroid() ;
	($$cx[$$countyAoiCtr],$$cy[$$countyAoiCtr]) = @$center ;
	$terrainData{$$pref{'id'}} = getTerrainData(@$center) ;
	#print " centroid=$$cx[$$countyAoiCtr],$$cy[$$countyAoiCtr]\n" ; 
	my %aoihash = ( 'id' => $$pref{'id'} , 'polygon' => \$nxtaoi ) ;
	push @$listofAois,\%aoihash ;
	$totalArea += $parea ;
	$$countyAoiCtr++ ;
	$aoiCtr++ ;
}
print "$aoiCtr AOIs recorded, total area of $totalArea: " ;
for my $cname (keys %countydata) {
	my $pc = $countydata{$cname}{'aois'};
	my $np = @$pc ;
	print "$cname -> $np ",
}
print "\n" ;


my (@clusters,@clustercenters,$numclusters,@tclusters,$nc) ;
$nc = $numclusters = 0;
foreach my $cn (keys %countydata)
{
	print "Trying K-means clustering for $cn \n" ;
	($clusters[$nc],$clustercenters[$nc],$tclusters[$nc]) = 
		aoiClusters($countydata{$cn}{'aois'},$countydata{$cn}{'cx'},$countydata{$cn}{'cy'},$totalArea) ;
	$countydata{$cn}{'clusterMap'} = $clusters[$nc] ;
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
	my %newst = makeNewOutlineStyle($nc,$colors[$nc]) ;
	$newstyle{'Style'} = \%newst ;
	push @$stylegroup, \%newstyle ;
}
for ($nc = 0; $nc<@browncolors; $nc++){
	print "Adding new style $nc\n" ;
	my %newstyle ;
	my %newst = makeNewSolidStyle($nc,$browncolors[$nc]) ;
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
			my $preflist = $countydata{$cn}{'aois'};
			foreach my $pref (@$preflist) {
				if ($$pref{'id'} eq $pk) {
					$pgon = $$pref{'polygon'} ;
					last ;
				}
			}
			if ($pgon == 0) {
				die "Couldn't find $pk in data for $counties[$i]\n" ;
			}
		#		if ($pgon == 0) {die "Can't find $pk in list of placemarks\n" ;}
			$$pgon->simplify() ;
			my @points = $$pgon->points() ;
			splice @clusterpoints,@clusterpoints,0,@points ;
			push @plist,$$pgon ;
		}
		#my $clusterpoly = chainHull_2D @clusterpoints ;
		my $clusterpoly = Math::Polygon->new(cvxPolygon::combinePolygonsConvex(\@plist)) ;
		printf "Convex operation returns polygon with %d points, closed=%d\n",$clusterpoly->nrPoints(),$clusterpoly->isClosed() ;
		my %options ;
		$options{''} = 1 ;
		@clusterpoints = $clusterpoly->points() ;
		my %cinf ;
		$cinf{'id'} = $newc;
		$cinf{'poly'} = $clusterpoly ;
		push @{$countydata{$cn}{'clusters'}} , \%cinf ;
	
		my $description = makeNewDescription("Cluster $newcn, county $cn") ;
		my $cstyle = sprintf("ClusterStyle%.3d",$newcn%@colors) ;
		my $newcluster = makeNewCluster($clusterpoly,\%pmlistentry,$newcn,$cstyle,$description) ;
		$newclusters[$newcn - $oldnc] = $newcluster ;
		$newcn++ ; printf("newcn -> $newcn\n") ;
	}
	$i++ ;
}
#Assign styles to placemarks
foreach my $pref (@placemarkhashes) {
	#my $styleid = findInClusters($$pref{'id'},$clusters) ;
	my $styleid = $terrainData{$$pref{'id'}};
	next unless ($styleid != -1) ;

	$$pref{'styleUrl'} = '#TerrainStyle' . sprintf("%.3d",$styleid%$nc) ;
#		print "Changing style to $$pref{'styleUrl'}\n" ;
}
	
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
printReport(\%countydata,$opt_r) ;
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
			push @list, ${$$aoisref[$i]}{'id'} ;
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
		printf FTMP "%s,%.6g,%.6g\n", ${$$aoisref[$aoi]}{'id'}, $$cxref[$aoi], $$cyref[$aoi] ;
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
	
sub getTerrainData{
	my @coords = shift ;
	my $brown = int($coords[0]+$coords[1]) ;
	return $brown%@browncolors ;
}

sub printReport{
	my $cdata = shift ;
	my $ofile = shift ;
	open (FREP,">", "$ofile") || die "Can't open $ofile for writing\n" ; 
	print FREP "County,Cluster id,Area (sq.miles),Number of Towers,List of CBGs\n" ;
	for my $cname (keys %$cdata) {
		my $clist = $$cdata{$cname}{'clusters'} ;
		print "Processing county $cname\n" ;
		my $clusterlist = $$cdata{$cname}{'clusterMap'} ;
		for my $cid (@$clist) {
			my $clusterarea = $milesperlat*$milesperlong*$$cid{'poly'}->area() ;
			my $twrs = int($clusterarea/20.0) ;
			printf FREP "%.10s,%10s,%.6g,%d,",$cname,$$cid{'id'},$clusterarea,$twrs;
			my $cbglist = $$clusterlist{$$cid{'id'}} ;
			for my $cbg (@$cbglist) {
				print FREP "$cbg: ";
			}
			print FREP "\n" ;
		}
	}
	close(FREP) ;
}


