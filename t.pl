#!/usr/bin/perl

use strict ;
use XML::LibXML;
use Getopt::Std;
use Data::Dumper ;
use Math::Polygon;
my $milesperlat = 69 ;
my $milesperlong = 54.6 ; 
$Data::Dumper::Indent = 1;

srand($$) ;

my %towerdata ;
our ($opt_f,$opt_o) ;
getopts('f:o:') ;
my $filename = $opt_f || die "Need a filename\n";
my $oh ;
undef ($oh) ;
if ($opt_o) {
	open ($oh, ">", $opt_o) || die "Couldn't open $opt_o for writing\n" ;
	print $oh <<OH
County,NW Lat,Long,SE Lat,Long,Cells,Area,Terrain Classification
OH
;
}
my $dom = eval {
    XML::LibXML->load_xml(location => $filename);
};

if($@) {
    # Log failure and exit
    print "Error parsing '$filename':\n$@";
    exit 0;
}

my $kml = $dom->documentElement;
printf "kml is a %s\n",ref($kml);
printf "kml->nodeName is:%s\n",$kml->nodeName;

my @polygons ;
$kml = $kml->getChildrenByTagName('Folder') ;
printf "Element is a %s of size %d\n", ref($kml), $kml->size() ;
my $node = $kml->pop ;
printf "Sub element is a %s of name %s\n",ref($node),$node->nodeName ;
my (@docfolders,@foldersub) ;
@foldersub = $node->getChildrenByLocalName("Document") ;
my $documents = 0 ;
my @polygons ; 
for (my $i = 0; $i < @foldersub; $i++) {
	my $doc = $foldersub[$i] ;
	my $folder = $doc->getChildrenByLocalName("Folder") || die "Can't find Document->Folder\n" ;
	while (my $fdr  = $folder->pop) {
		findPolygonInFolder("", $fdr,\@polygons) ;
	}
}

for my $td (keys %towerdata) {
	print $oh "$td,$towerdata{$td}{'nw'},$towerdata{$td}{'se'},$towerdata{$td}{'ncells'},$towerdata{$td}{'area'},Unknown\n" ;
}
close ($oh) ;

sub findPolygonInFolder {
	my $cname = shift ;
	my $folder = shift ;
	my $plist = shift ;
	my ($nf,$np) ;
	my @subfolders = $folder->getChildrenByLocalName("Folder") ;
	my @pmarks = $folder->getChildrenByLocalName("Placemark") ;
	$nf = @subfolders; $np  = @pmarks ;
	print "Processing folder $cname\n" ;
	my @names = $folder->getChildrenByTagName("name") ;
	for my $pmark (@pmarks) {
		my @pgon = $pmark->getChildrenByLocalName("Polygon") ;
		my @styles = $pmark->getChildrenByLocalName("StyleUrl") ;
		my $pname = "noname". rand(100) ;
		if (@names && @pgon) {
			my $np = $names[0]->textContent ;
			$np =~ tr/\r\n// ;
			printf "Name of placemark with polygon:%s\n",$np ;
			for my $pgn (@pgon) { 
				my $poly = xmlToPolygon($pgn,$np) ;
				push @$plist, $poly,
			}
		}
	}
	if (@names && ($names[0]->textContent eq "Selected Cells")) {
		my $towers = xmlToSelectedCells($cname,$folder) ;
		print "$towers cell sites in $cname\n" ;
		$towerdata{$cname}{'ncells'} = $towers ; 
	}
	for my $fdr (@subfolders) {
		if ($cname eq "") { my $temp = $names[0]->textContent ; $cname .= $temp ; }
		findPolygonInFolder($cname,$fdr,$plist) ;
	}
}
my $polygon = @polygons;
print "$polygon polygons identified\n" ;

sub xmlToPolygon {
	my @parray ; 
	my $kid =shift ;
	my $cname = shift ;
	{ 
		#	printf "%s, %s\n",ref($kid),$kid->nodeName;
		my @polygonkids = $kid->getChildrenByLocalName("outerBoundaryIs") ;
		for my $i (@polygonkids) {
			#		printf "%s->%s\n", ref($i),$i->nodeName ;
			my @clist = $i->getChildrenByLocalName("LinearRing") ;
			for my $j (@clist) {
				my @plist = $j->getChildrenByLocalName("coordinates") ;
				for my $k (@plist) {
					my $tdata = $k->textContent ;
					chomp($tdata) ;
					my @coords = split(/\s+/,$tdata) ;
					for my $crd (@coords) {
						my (@xy,$z);
						($xy[0],$xy[1],$z) = split(/,/,$crd); 
						if (defined($xy[0]) && defined($xy[1])) {
							push @parray,\@xy ;
						}
					}
				}
			}
		}
	}
	my ($fst,$lst) ;
	$fst = $parray[0] ;
	$lst = $parray[$#parray] ;
	if ($$fst[0] != $$lst[0] || $$fst[1] != $$lst[1]) {
		print "Polygon is not closed\n" ;
		my @newlst = @$fst ;
		push @parray,\@newlst;
	}

	my $pgon = Math::Polygon->new(@parray) ;
	if ($pgon->isClosed != 1) { print "Polygon is still not closed\n" ; }
	printf "Polygon in %s with %d points, %.4g area ", $cname, $pgon->nrPoints, $pgon->area()*$milesperlat*$milesperlong ;
	my ($xmin,$ymin,$xmax,$ymax) = $pgon->bbox ;
	print "\n$xmin,$ymin,$xmax,$ymax\n" ;
	if (!defined($towerdata{$cname})) {
	       my %tdata ;
       		$tdata{'area'} = $pgon->area()*$milesperlat*$milesperlong;	       
		$tdata{'nw'} = sprintf("%.10g,%.10g",$ymax,$xmin) ;
		$tdata{'se'} = sprintf("%.10g,%.10g",$ymin,$xmax) ;
		$towerdata{$cname} = \%tdata ;
	}
	else {
		$towerdata{$cname}{'area'} += $pgon->area()*$milesperlat*$milesperlong;
		my ($oldymax,$oldxmin) = split (/,/, $towerdata{$cname}{'nw'}) ;
		my ($oldymin,$oldxmax) = split (/,/, $towerdata{$cname}{'se'}) ;
		if ($oldymax < $ymax || $oldxmin > $xmin) {
			$towerdata{$cname}{'nw'} = sprintf("%.10g,%.10g",$ymax,$xmin) ;
		}
		if ($oldymin > $ymin || $oldxmax < $xmax) {
			$towerdata{$cname}{'se'} = sprintf("%.10g,%.10g",$ymin,$xmax) ;
		}
	}
	return $pgon ;
}

sub xmlToSelectedCells {
	my $cname = shift ;
	my $fdr = shift ;
	my $twrs = 0 ;
	my @cellLoc ;
	my @names = $fdr->getChildrenByTagName("name") ;
	my @pmarks = $fdr->getChildrenByTagName("Placemark") ;
	if (@names)  {printf "name:%s\n", $cname . $names[0]->textContent ; }
	for my $pmark (@pmarks) {
		my @tsites = $pmark->getChildrenByTagName("Point") ;
		my @coords = $tsites[0]->getChildrenByTagName("coordinates") ;
		my @location = $coords[0]->textContent ;
		push @cellLoc,\@location ;
		$twrs++ ;
	}
	if (!defined($towerdata{$cname})) {
		my %tdata ;
		$tdata{'ncells'} = $twrs ;
	#$tdata{'cellpositions'} = \@cellLoc ;
		$towerdata{$cname} = \%tdata ;
	}
	else {
		$towerdata{$cname}{'ncells'} = $twrs ;
	}
	return $twrs;
}
#print Dumper $kml->toString() ;
#

sub printElement {
	my $ele = shift ;
	my $indent = shift ;
	my @nodes = $ele->getChildrenByLocalName("*");
	my $numnodes = @nodes ;
	#if ($ele->nodeName eq "Polygon" || $ele->nodeName eq "Placemark")
	{
		printf "%s Element is a %s of name %s, %d children\n", $indent, ref($ele) ,$ele->nodeName,$numnodes ;
	}
	if ($ele->nodeName eq "Polygon") { return ; }
	$indent .= "\t" ;
	for my $nd (@nodes) {
		printElement($nd,$indent) ;
	}
}

sub printNodeList {
	my $ele = shift ;
	printf "Element is a %s of size %d \n", ref($ele),$ele->size() ;
	my $node ;
		while ($node = $ele->pop) {
		#		if ($node->nodeType == XML_ELEMENT_NODE) { printNode($node) ;}
		#	printElement($node) ;
			printf "Element of name %s\n",$node->nodeName ;
			my @nodes = $ele->getChildrenByLocalName("*");
			my $numnodes = @nodes ;
		}
}

sub printNode {
	my $ele = shift ;
	printf "Element is a %s of name %s\n", ref($ele),$ele->nodeName ;
}
