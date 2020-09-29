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
use terraindB ;
use nlcd;

$Data::Dumper::Indent = 1;
my $milesperlat = 69 ;
my $milesperlong = 54.6 ; 
my $prompt = 1;


our $opt_f = "" ;
our $opt_k = "" ;
our $opt_r = "sampleReport.csv" ;
our $opt_K = "proximity3" ;
our $opt_t = "" ;
our $opt_h ;
our $opt_p = 0 ;
our $opt_t = "" ;
our $opt_w = "" ;
getopts('f:k:r:K:t:hw:') ;
if ($opt_h) {
	print "Usage:kmz.pl -f <input kmz file> -k <output kmz file> -r <report file> -t <terrain db> -K <Kmeans/proximity>\n";
	exit(1) ;
}
my @colors = (0xffff0000, 0xff00ff00, 0xff0000ff, 0xffaa3333, 0xff33aa22,0xff00cccc, 0xff22cc22, 0xff22aacc) ;
my @polycolors = (0xfffff8dc, 0xffffe4c4, 0xfff5deb3, 0xffd2b48c, 0xff90ed90,0xffadff2f, 0xff32cd32, 0xff228b22) ;
my %pmlistentry ;

#
# We need a file to load
#
my $statename = "" ;
if ($opt_f eq "") {
	die "Usage: kmz.pl -f <input file> [-c to cluster] [-k <output kml file>]\n" ;
}
else {
	if ($opt_f =~ m@.*/([A-Z]{2}).kmz@) {
		$statename = $1 ;
	}
	else {
		print "No Statename\n" ;
	}

	open(F1,$opt_f) || die "Can't open file $opt_f\n" ; 
	if ($opt_k eq "") {
		($opt_f =~ m@.*([A-Z]{2}).kmz@) && 
			do {
				$opt_k = $1 . "mod.kmz" ; 
				print "output kmz file=$opt_k\n"; 
			} ;
	}
}
my (@whitelist,@wlist) ;
if ($opt_w) {
	open (WL,$opt_w) || die "Can't open $opt_w for whitelist reading\n" ;
	while (<WL>) {
		if (/(\d+),([A-Z]+)/) {
			if ($2 eq $statename) { 
				push @wlist,$1 ;
			}
		}
	}
	my $nw = @wlist ;
	@whitelist = sort {$a <=> $b} @wlist ;
	print "$nw entries loaded\n" ;
}

#
# See if terrain db exists...in which case it gets loaded. Else, we will have to write to it
#

my %terraindB ;
my %srtmDB ;
my $tdbAvail = 0;
my @sbbox ;
if (($opt_t ne "") && (-e $opt_t) && (terraindB::loadTerrainDB($opt_t,\%terraindB,\@sbbox) == 1) )
{
	print "Loaded Terrain DB from $opt_t\n" ;
	$tdbAvail = 1 ;
}


if ($opt_p) { $prompt = 0 ; }

srand($$) ;

# 
# Process the file and load placemarks. Each Placemark is a CBG
# The county information is in the description
#
print "Opening $opt_f for processing...\n" ;
my ($ns,$data) = Geo::KML->readKML($opt_f) ;
my $dhash = %$data{'Document'} ;
#for (keys %$dhash) {
#	print "Key $_: Value $$dhash{$_}\n" ;
#}
my $featuregroup = $$dhash{'AbstractFeatureGroup'} ;
my $stylegroup = $$dhash{'AbstractStyleSelectorGroup'} ;

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
# 
# Now convert placemarks into polygons
#
foreach my $pref (@placemarkhashes) {
	my $countyAoiCtr = 0;
	my $geometries = $$pref{'MultiGeometry'}{'AbstractGeometryGroup'} ;
	my $description = $$pref{'description'} ;
	if ($opt_w && !whiteListed(\@whitelist,$$pref{'name'})) {
		foreach my $geomkey (@$geometries) {
			undef $$geomkey{'Polygon'}{'altitudeMode'} ;
		}
		next ;
	}

	my ($county,$new) = getCounty($description,\@counties) ;
	print "County $county\n" ;
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
	my %tdata ; 
	{
			my %histogram ;
			my $npts = int($nxtaoi->area()*$milesperlat*$milesperlong)+1 ;
			print "Calling samplehistogram with $npts points\n" ;
			nlcd::sampleHistogram($nxtaoi,$npts*100,\%histogram) ;
			my $totalrange = @polycolors ;
			$tdata{'terrainType'} = getTerrainCodeFromHistogram(\%histogram,$totalrange); 
	}
	$tdata{'area'} = $parea  ;
	$terrainData{$$pref{'name'}} = \%tdata ;
	if (!$tdbAvail) {
		my %tdbEntry ;
		my (@se,@nw) ;
		($nw[0],$se[1],$se[0],$nw[1]) = $nxtaoi->bbox ;
		$tdbEntry{'county'} =  $county ;
		$tdbEntry{'SouthEast'} = \@se ;
		$tdbEntry{'NorthWest'} = \@nw ;
		$tdbEntry{'centroid'} = $center ;
		$tdbEntry{'area'} = $parea ;
		$terraindB{$$pref{'name'}} = \%tdbEntry ;
	}
		
		
	#print " centroid=$$cx[$$countyAoiCtr],$$cy[$$countyAoiCtr]\n" ; 
	my %aoihash = ( 'name' => $$pref{'name'} , 'polygon' => \$nxtaoi ) ;
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
if (!$tdbAvail && $opt_t ne "") {
	terraindB::printTerrainDB($opt_t, \%terraindB) ;
}

#
# Clustering
#

my (@clusters,@clustercenters,$numclusters,@tclusters,$nc) ;
$nc = $numclusters = 0;
foreach my $cn (keys %countydata)
{
	my @aois = @{$countydata{$cn}{'aois'}} ;
	if ($opt_K eq "Kmeans" && (@aois > 9)) {
		print "Trying K-means clustering for $cn \n" ;
		($clusters[$nc],$clustercenters[$nc],$tclusters[$nc]) = 
			aoiClustersKmeans($countydata{$cn}{'aois'},$countydata{$cn}{'cx'},$countydata{$cn}{'cy'},$totalArea) ;
	}
	#elsif ($opt_K eq "proximity") {
	else {
		my $thresh = 5 ;
		($opt_K =~ /proximity([.0-9]+)/) && do {
			$thresh = $1 ; 
		} ;
		print "Trying Proximity clustering for $cn ($thresh) \n" ;
		($clusters[$nc],$tclusters[$nc]) = 
			aoiClustersProximity($countydata{$cn}{'aois'},$thresh) ;
			die unless (prompt(\$prompt) == 1) ;
	}
	#	else {
	#	die "Unknown clustering method $opt_K\n" ;
	#}
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
# 
# Create new styles, to be allocated randomly to clusters
#
for ($nc = 0; $nc<@colors; $nc++){
	print "Adding new style $nc\n" ;
	my %newstyle ;
	my %newst = makeNewOutlineStyle($nc,$colors[$nc]) ;
	$newstyle{'Style'} = \%newst ;
	push @$stylegroup, \%newstyle ;
}
# 
# Create new terrain styles, to be allocated randomly to clusters
#
for ($nc = 0; $nc<@polycolors; $nc++){
	print "Adding new style $nc\n" ;
	my %newstyle ;
	my %newst = makeNewSolidStyle($nc,$polycolors[$nc]) ;
	$newstyle{'Style'} = \%newst ;
	push @$stylegroup, \%newstyle ;
}
#
# Make a new grey style
my (%greystyle,%greyst,$greyid) ;
$greyid = @polycolors ;
%greyst = makeNewSolidStyle($greyid,0xff708090) ;
$greystyle{'Style'} = \%greyst ;
push @$stylegroup,\%greystyle ;

my $newcn = $oldnc ;

#
# Now each cluster is enclosed in a single, convex polygon
#
my $i = 0;
my @newfolders ;
foreach my $cn (keys %countydata)
{
	my @newclusters ;
	my $ccn = 0 ;
	foreach my $newc (keys %{$clusters[$i]}) {
		my @clusterpoints ;
		my @clist = @{$clusters[$i]->{$newc}} ;
		my @plist ;
		my $cliststring = "" ;
		print "newc = $newc newcn = $newcn\n" ;
		for my $pk (@clist){
			my $pgon = 0 ;
			my $preflist = $countydata{$cn}{'aois'};
			$cliststring .= sprintf("%s\n",$pk) ;
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
			$$pgon->simplify() ;
			my @points = $$pgon->points() ;
			splice @clusterpoints,@clusterpoints,0,@points ;
			push @plist,$$pgon ;
		}
		my $badclusterpoly = chainHull_2D @clusterpoints ;
		my $clusterpoly = Math::Polygon->new(cvxPolygon::combinePolygonsConvex(\@plist)) ;
		printf "Convex operation returns polygon with %d points, closed=%d\n",$clusterpoly->nrPoints(),$clusterpoly->isClosed() ;
		my %options ;
		$options{''} = 1 ;
		@clusterpoints = $clusterpoly->points() ;
		my %cinf ;
		$cinf{'name'} = $newc;
		$cinf{'poly'} = $badclusterpoly ;
		push @{$countydata{$cn}{'clusters'}} , \%cinf ;

		my $description = makeNewDescription("Cluster $newcn, county $cn List of CBGs:$cliststring") ;
		my $cstyle = sprintf("ClusterStyle%.3d",$newcn%@colors) ;
		my $newcluster = makeNewCluster($cn,$clusterpoly,\%pmlistentry,$ccn,$cstyle,$description) ;
		#$newclusters[$newcn - $oldnc] = $newcluster ;
		push @newclusters, $newcluster ;
		$newcn++ ; $ccn++ ; 
		#printf("newcn -> $newcn\n") ;
	}
	my %newfolder ; 
	my %foldercontainer ;
	makeNewFolder($cn,\@newclusters, \%newfolder) ;
	$foldercontainer{'Folder'} = \%newfolder ;
	push @newfolders, \%foldercontainer ;
	$i++ ;
}
#
# Assign styles to placemarks
#
foreach my $pref (@placemarkhashes) {
	#my $styleid = findInClusters($$pref{'name'},$clusters) ;
	my $styleid ;
	if ($opt_w && !whiteListed(\@whitelist,$$pref{'name'})) {
		$styleid = $greyid ;
	}
	else {
		$styleid = $terrainData{$$pref{'name'}}{'terrainType'}%$nc;
	}
	next unless ($styleid != -1) ;

	$$pref{'styleUrl'} = '#TerrainStyle' . sprintf("%.3d",$styleid) ;
#		print "Changing style to $$pref{'styleUrl'}\n" ;
}
#splice @{$featureref[0]},@{$featureref[0]},0,@newclusters ;
#splice @$featuregroup, @$featuregroup, @newfolders ;
for my $fg (@newfolders) {
	push @$featuregroup, $fg ;
}
for my $fg (@$featuregroup) {
	print "$fg " ;
}
print "\n" ;


#open (ODAT, ">/tmp/odat.txt") || die "Can't open odat.txt for writing\n" ;
#print ODAT Dumper $data ;
#close (ODAT) ;
# 
# Write back to output kml/kmz file. Note that for kmz file you have to set
# zip option, its not automatic
#
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
#
# printReport
#
printReport(\%countydata,$opt_r,\%terrainData) ;
#
# Last step. Dump the state bounding boxes on the screen

exit(1) ;


use Algorithm::KMeans ;
sub aoiClustersKmeans{
	my $aoisref = shift ;
	my $cxref = shift ;
	my $cyref = shift ;
	my $tA = shift ;
	my $nc = 0;
	my $datafile = "aoi" . $$ . ".csv" ;
	my $kmin = int($tA/2000) ;
	my $kmax = int(sqrt(@$aoisref/2)) ;
	print "Initial estimate kmax=$kmax kmin=$kmin\n" ; 
	#	if (@$aoisref < 9) {
	#	my @list ;
	#	my @center = ($$cxref[0],$$cyref[0]) ;
	#	for (my $i = 0 ; $i <@$aoisref; $i++) {
	#		push @list, ${$$aoisref[$i]}{'name'} ;
	#	}
	#	my %sc ;
	#	$sc{'cluster0'} = \@list;
	#	return (\%sc, \@center,1) ;
	#}


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

use proximityCluster ;
sub aoiClustersProximity{
	my $aoisref = shift ;
	my $thresh = shift ;
	my @boxes ;
	for (my $aoi=0 ; $aoi < @$aoisref; $aoi++) {
		my %box ;
		$box{'id'} = ${$$aoisref[$aoi]}{'name'} ;
		my $poly =  $$aoisref[$aoi]{'polygon'} ;
		my $cnt = $$poly->centroid ;
		$box{'centroid'} = $cnt ;
		$box{'area'} = $$poly->area * $milesperlat * $milesperlong ;
		#printf "Polygon of centroid %.4g,%.4g, area %.4g\n", $$cnt[0], $$cnt[1], $$poly->area ;
		push @boxes,\%box ;
	}
	my $nb = @boxes ;
	print "Produced array of size $nb boxes\n" ;
	my %clusters = proximityCluster::proximityCluster(\@boxes,$thresh) ;
	my $nc = 0 ;
	foreach my $cluster_id (sort keys %clusters) {
		print "\n$cluster_id   =>   @{$clusters{$cluster_id}}\n";
		$nc++ ;
	}
	return \%clusters,$nc ;
}

sub prompt{
	my $continue = shift ;
	if ($$continue == 1) { return 1 ; }
	else {
		print ("Continue? [Y/n/c]\n") ;
		$_ = <> ;
		chomp ;
		if ($_ eq 'c') { $$continue = 1 ; return 1 ; }
		elsif ($_ eq 'n') { return 0 ; }
		else { return 1 ; }
	}
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
	if ($dstr =~ m@<td>county</td>\s*<td>([^<]+)</td>@s) {
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
	

sub printReport{
	my $cdata = shift ;
	my $ofile = shift ;
	my $tdata = shift ;
	my @terrainDensity = (75, 70, 65,60,55,50,45,40) ;
	#	print Dumper $tdata ;
	#return 0;
	open (FREP,">", "$ofile") || die "Can't open $ofile for writing\n" ; 
	print FREP "County,Cluster id,Area (sq.miles), CBG ARea, %Coverage, Weighted Terrain Code,Number of Towers,List of CBGs\n" ;
	print "Processing counties..." ;
	my ($totalArea,$totalTowers,$totalCbgArea) ;
	$totalArea = $totalTowers = $totalCbgArea = 0 ;
	for my $cname (sort keys %$cdata) {
		my $clist = $$cdata{$cname}{'clusters'} ;
		print "[$cname] " ;
		my $clusterlist = $$cdata{$cname}{'clusterMap'} ;
		my $listofAois = $$cdata{$cname}{'aois'} ;
		my %aoiArea ;
		my %towers;
		my %terrainCode ;
		for my $aoi (@$listofAois) {
			#print "Name $$aoi{'name'}..." ;
			my $poly = $$aoi{'polygon'} ;
			$aoiArea{$$aoi{'name'}} = $$poly->area * $milesperlat * $milesperlong ; 
			#printf "area = %.4g..", $$poly->area ;
			$terrainCode{$$aoi{'name'}} = $$tdata{$$aoi{'name'}}{'terrainType'} ;
			my $cellDensity = $terrainDensity[0] - 5*$terrainCode{$$aoi{'name'}} ;
			print "terrain=$terrainCode{$$aoi{'name'}} density=$cellDensity\n" ;
			my $aoiTower = int($aoiArea{$$aoi{'name'}}/$cellDensity) ;
			if ($aoiTower < 1) { $aoiTower = 1;}
			$towers{$$aoi{'name'}} += $aoiTower ;
		}

		for my $cid (@$clist) {
			my $clusterarea = $milesperlat*$milesperlong*$$cid{'poly'}->area() ;
			my $ostring = "" ;
			my $cbgClusterArea = 0 ; 
			my $twrs = 0;
			my $weightedTerrainCode= 0 ;
			my $cbglist = $$clusterlist{$$cid{'name'}} ;
			for my $cbg (@$cbglist) {
				$ostring .= "$cbg:" ;
				$cbgClusterArea += $aoiArea{$cbg} ;
				$twrs += $towers{$cbg} ;
				$weightedTerrainCode += $terrainCode{$cbg}*$aoiArea{$cbg} ;
			}
			$weightedTerrainCode = int($weightedTerrainCode/$cbgClusterArea) ;
			my $pc = int(100.0*($cbgClusterArea/$clusterarea)) ; 
			printf FREP "%.10s,%10s,%.6g,%.4g,%d%%,%d,%d,",
				$cname,$$cid{'name'},$clusterarea,$cbgClusterArea,$pc,
				$weightedTerrainCode,$twrs;
			print FREP "$ostring\n" ;
			$totalArea += $clusterarea ;
			$totalCbgArea += $cbgClusterArea ;
			$totalTowers += $twrs ;
		}
	}
	print "\n";
	print FREP "Towers = $totalTowers\nArea = $totalArea\nCBG Area = $totalCbgArea\n" ;
	close(FREP) ;
}

sub whiteListed {
	my $wlist = shift ;
	my $entry = shift ;
	for (my $i = 0; $i<@$wlist; $i++) {
		if ($entry == $$wlist[$i]) { return 1 ; }
		#elsif ($entry > $$wlist[$i]) { return 0 ; }
	}
	return 0;
}

sub getTerrainCodeFromHistogram {
	my $hist = shift ;
	my $range = shift ;
	my ($forest,$urban,$wet,$good)  ;
	my ($total) ;
	my $ret ;
	print "getTerrainCode:" ;
	$forest = $$hist{41} + $$hist{42}+ $$hist{43} ;
	$urban = $$hist{22} + $$hist{23} + $$hist{24} ;
	$wet = $$hist{11} + $$hist{12} + $$hist{90} + $$hist{95} ;
	$total = 0 ;
	for my $nlcd (keys %$hist) {
		print "$nlcd=>$$hist{$nlcd} " ;
		$total += $$hist{$nlcd} ;
	}
	print "forest = $forest, urban=$urban, wet = $wet " ;
	$ret = ($forest + $urban + $wet)/$total ;
	print "ret=$ret\n" ;
	return int($ret * $range) ;
}
