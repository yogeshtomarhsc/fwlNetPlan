#!/usr/bin/perl
#


use strict ;
use Getopt::Std ;
use Geo::KML ;
use Data::Dumper ;
use XML::LibXML ;
use Math::Polygon ;

my $milesperlat = 69 ;
my $milesperlong = 54.6 ; 

our $opt_f = "" ;
our $df = "kml.dat" ;
my $odf = "kmlmod.dat" ;
our $opt_c = 0 ;
our $opt_w = 0 ;
our $opt_k = "" ;
getopts('f:wck:') ;
my $keyv ;
my @colors = (0xffff0000, 0xff00ff00, 0xff0000ff, 0xffaa3333, 0xff33aa22,0xff00cccc, 0xff22cc22, 0xff22aacc) ;

if ($opt_f eq "") {
	die "Usage: kmz.pl -f <input file> [-o decompiled file] [-w to wait] [-c to cluster] [-k <output kml file>]\n" ;
}
else {
	open(F1,$opt_f) || die "Can't open file $opt_f\n" ; 
	open(F2,">",$df) || die "Can't open file $df for writing\n" ; 
	open(F3,">",$odf) || die "Can't open file $odf for writing\n" ; 
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
#exit(1) ;

#defined $ns or die "don't understand file content\n";
#print "$ns\n" ;

#my $dom = XML::LibXML->load_xml(string => $data);
#foreach my $title ($dom->findnodes('coordinates')) {
#    say $title->to_literal();
#}
#
$Data::Dumper::Indent = 1;
#
my $EPS = 0.001 ;
my $totalArea = 0 ;
my @aois ;
my (@cx,@cy) ;
my $aoiCtr=0;
my $cxavg = 0 ;
my $cyavg = 0 ;
my @placemarkhashes;
my $placemarks = 0;
foreach my $fg (@$featuregroup) {
	for my $fkey (keys %$fg) {
		print "Key $fkey: Value $$fg{$fkey}\n" ;
		next unless ($fkey eq 'Folder') ;
		my $fder = %$fg{$fkey} ;
		for my $fderkey (keys %$fder) {
			print "Folder Key $fderkey: Value $$fder{$fderkey}\n" ;
			next unless ($fderkey eq 'AbstractFeatureGroup') ;
			my $features  = $$fder{'AbstractFeatureGroup'} ;
			foreach my $fcount (@$features)
			{
				for my $fcntkey (keys %$fcount) {
					print "Feature Key $fcntkey: Value $$fcount{$fcntkey}\n" ;
					if ($fcntkey eq 'Placemark') { push @placemarkhashes,$$fcount{$fcntkey} ; $placemarks++; }
				}
			}
		}
		
	}
}
print "$placemarks Placemarks found\n" ;

use Math::Polygon::Convex qw/chainHull_2D/ ;

foreach my $pref (@placemarkhashes) {
	my $geometries = $$pref{'MultiGeometry'}{'AbstractGeometryGroup'} ;
	my @pcoords ;
	foreach my $geomkey (@$geometries) {
		my $coordinates = $$geomkey{'Polygon'}{'outerBoundaryIs'}{'LinearRing'}{'coordinates'} ;
		my @plist = arrayToPolygon($coordinates) ;
		splice @pcoords,@pcoords,0,@plist ;

		undef $$geomkey{'Polygon'}{'altitudeMode'} ;
	#{ print "coordinate string: $$geomkey{'Polygon'}{'outerBoundaryIs'}{'LinearRing'}{'coordinates'}\n" ; }
	}
	my $nxtaoi = chainHull_2D @pcoords ;
	my $pcnt = $nxtaoi->nrPoints ;
	my $parea = $nxtaoi->area()*$milesperlat*$milesperlong ;
	printf "Converted placemark to convex hull of %d points, area = %.4g (closed=%d) ", $pcnt,$parea,$nxtaoi->isClosed() ;
	#			print "Polygon created of $pcnt points, area=$parea, centroid=$cx[$aoiCtr],$cy[$aoiCtr]\n" ; 
	next unless ($parea > $EPS) ;
	next unless ($nxtaoi->isClosed()) ;
	my $center =  $nxtaoi->centroid() ;
	($cx[$aoiCtr],$cy[$aoiCtr]) = @$center ;
	print " centroid=$cx[$aoiCtr],$cy[$aoiCtr]\n" ; 
	my %aoihash = ( 'name' => $$pref{'name'} , 'polygon' => \$nxtaoi ) ;
	#	push @aois,$nxtaoi ;
	push @aois,\%aoihash ;
	$totalArea += $parea ;
	$aoiCtr++ ;
	if ($opt_w == 0)  { next ; }
	last unless (($keyv = waitKey()) != 0) ;
	if ($keyv == 2) {$opt_w = 0 ; }
}
print "$aoiCtr AOIs recorded, total area of $totalArea: " ;


my ($clusters,$clustercenters, $numclusters) ;
if ($opt_c) {
	print "Trying K-means clustering\n" ;
	($clusters,$clustercenters,$numclusters) = aoiClusters(\@aois,\@cx,\@cy) ;
	print "$numclusters clusters returned\n" ;
}
else {
	$numclusters = @colors ;
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
for (; $nc<$numclusters; $nc++){
	print "Adding new style $nc\n" ;
	my %newstyle ;
	my %newst = makeNewStyle($nc) ;
	$newstyle{'Style'} = \%newst ;
	push @$stylegroup, \%newstyle ;
}
#Assign styles to placemarks
foreach my $pref (@placemarkhashes) {
	my $styleid = findInClusters($$pref{'name'},$clusters) ;
	next unless ($styleid != -1) ;
	$$pref{'styleUrl'} = '#PolyStyle' . sprintf("%.2d",$styleid%$nc) ;
	#	print "Changing style to $$pref{'styleUrl'}\n" ;
}

print "Writing to kmlmod.dat\n" ;
my $strdata = Dumper($data);
print F3 "$strdata\n" ;
close(F3) ;

print "Writing to kmz file $opt_k\n" ;
my $opkml = Geo::KML->new(version => '2.2.0') ;
$opkml->writeKML($data,$opt_k) ;
exit(1) ;

sub makeNewStyle{
	my %newst ;
	my $num = shift ;
	my $styleid = "PolyStyle" . sprintf("%.2d",$num) ;
	my ($red,$blue,$green) ;
	$red = int(rand(255)) ;
	$blue = int(rand(255)) ;
	$green = int(rand(255)) ;
	my $clr = (0xff<<24) | (($blue) << 16) | (($green) << 8) | ($red)  ;
	$newst{'id'} = $styleid ;
	$newst{'PolyStyle'} = {'color' => $clr, 'outline' => 1} ;
	$newst{'LabelStyle'} = { 'color' => $clr, 'scale' => 0.0000 } ;
	$newst{'LineStyle'} = { 'color' => $clr, 'width' => 0.4000 } ;
	%newst ;
}

use Algorithm::KMeans ;
sub aoiClusters{
	my $aoisref = shift ;
	my $cxref = shift ;
	my $cyref = shift ;
	my $nc = 0;
	my $datafile = "aoi" . $$ . ".csv" ;
	my $kmax = int(sqrt(@$aoisref)) ;
	if ($kmax > 12) { $kmax = 12 ; }
	open (FTMP, ">",$datafile) || die "Can't open $datafile for creating cluster list\n" ;
	for (my $aoi=0 ; $aoi < @$aoisref; $aoi++) {
		printf FTMP "%s,%.6g,%.6g\n", ${@$aoisref[$aoi]}{'name'}, @$cxref[$aoi], @$cyref[$aoi] ;
	}
	close (FTMP) ;
	print "Trying K-means with $kmax clusters\n" ;
	my $clusterer = Algorithm::KMeans->new(
		datafile        => $datafile,
                mask            => "N11",
                K               => 0,
		Kmin		=> 6,
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


sub waitKey
{
	my $keyinput = <> ;
	chomp($keyinput) ;
	if ($keyinput eq "") { return 1 ; }
	else {
		print "$keyinput\n" ;
		if ($keyinput eq "q") {
			return 0 ;
		}
		elsif ($keyinput eq "c") {
			return 2 ; 
		}
		else { return 1 ; }
	}
}
