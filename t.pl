#!/usr/bin/perl

use strict ;
use XML::LibXML;
use Getopt::Std;
use Data::Dumper ;
use Math::Polygon;
my $milesperlat = 69 ;
my $milesperlong = 54.6 ; 
$Data::Dumper::Indent = 1;

our ($opt_f,$opt_x) ;
getopts('f:') ;
my $filename = $opt_f || die "Need a filename\n";
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
		printf "fdr of type %s\n",ref($fdr) ;
		findPolygonInFolder($fdr,\@polygons) ;
	}
}

sub findPolygonInFolder {
	my $folder = shift ;
	my $plist = shift ;
	my ($nf,$np) ;
	my @subfolders = $folder->getChildrenByLocalName("Folder") ;
	my @pmarks = $folder->getChildrenByLocalName("Placemark") ;
	$nf = @subfolders; $np  = @pmarks ;
	print "Found $nf subfolders $np placemarks\n" ;
	for my $pmark (@pmarks) {
		my @pgon = $pmark->getChildrenByLocalName("Polygon") ;
		for my $pgn (@pgon) { 
			my $poly = xmlToPolygon($pgn) ;
			printf "Found polygon in placemark\n" ; 
			push @$plist, $poly,
		}
	}
	for my $fdr (@subfolders) {
		findPolygonInFolder($fdr,$plist) ;
	}
}
my $polygon = @polygons;
print "$polygon polygons identified\n" ;

sub xmlToPolygon {
	my @parray ; 
	my $kid =shift ;
	{ 
		#	printf "%s, %s\n",ref($kid),$kid->nodeName;
		my @polygonkids = $kid->getChildrenByLocalName("outerBoundaryIs") ;
		for my $i (@polygonkids) {
			#		printf "%s->%s\n", ref($i),$i->nodeName ;
			my @clist = $i->getChildrenByLocalName("LinearRing") ;
			for my $j (@clist) {
				my @plist = $j->getChildrenByLocalName("coordinates") ;
				for my $k (@plist) {
					my @coords = split(/\s+/,$k->textContent) ;
					for my $crd (@coords) {
						my (@xy,$z);
						($xy[0],$xy[1],$z) = split(/,/,$crd); 
						push @parray,\@xy ;
					}
				}
			}
		}
	}
	my $pgon = Math::Polygon->new(@parray) ;
	my $points = @parray ;
	printf "Polygon with %d points, %.4g area\n",$points, $pgon->area()*$milesperlat*$milesperlong ;
	return $pgon ;
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
