#!/usr/bin/perl
package terraindB;

require Exporter ;
use strict;
use Data::Dumper ;
$Data::Dumper::Indent = 1;

our @ISA = qw(Exporter);
our @EXPORT = qw(getTerrainCode loadTerrainDB printTerrainDB);
my $nBrownColors = 8 ;
sub getTerrainCode{
	my @coords = shift ;
	my $pname = shift ;
	my $tdbAvail = shift ;
	my $tdb = shift ;
	my $brown ;
	if (($tdbAvail != 1) ||
		!defined($$tdb{$pname})) {
		$brown = int(100.0*($coords[0]+$coords[1])) ;
	}
	else {
		$brown = $$tdb{$pname}{'terrainCode'} ;
	}
	return $brown%$nBrownColors ;
}

sub loadTerrainDB {
	my $tfname = shift ;
	my $tdb = shift ;
	my $bbox = shift ;
	my %keys ;
	my $tdbentries = 0;
	my ($sxmin, $sxmax, $symin, $symax) ;
	$sxmax = $symax = -10000.0 ;
	$sxmin = $symin = 10000.0 ;
	print "Entered load Terrain dB:filename = $tfname\n" ;
	$keys{'cbgid'} =  -1;
	open (FH, $tfname) || die "Can't open filename $tfname for reading:$!\n" ;
	while (<FH>) {
		/^#.*/ && next ;
		/^\s+$/ && next ;
		my @colhds = split (/,/) ;
		if ($keys{'cbgid'} == -1) {
			for (my $hdrid = 0; $hdrid < @colhds; $hdrid++) {
				($colhds[$hdrid] =~ /county/i) && do { $keys{'county'} = $hdrid ; };
				($colhds[$hdrid] =~ /SE Lat/i) && do { $keys{'selat'} = $hdrid ; };
				($colhds[$hdrid] =~ /SE Long/i) && do { $keys{'selong'} = $hdrid ; };
				($colhds[$hdrid] =~ /NW Lat/i) && do { $keys{'nwlat'} = $hdrid ; };
				($colhds[$hdrid] =~ /NW Long/i) && do { $keys{'nwlong'} = $hdrid ; };
				($colhds[$hdrid] =~ /cbg id/i) && do { $keys{'cbgid'} = $hdrid ; };
				($colhds[$hdrid] =~ /terrain\s*code/i) && do { $keys{'terrainCode'} = $hdrid ; };
			}
			if ($keys{'cbgid'} != -1) {
				print "Found col headings: " ;
				for my $keyname (sort keys %keys) {
					print "$keyname:$keys{$keyname} ";
				}
				print "\n" ;
			}
		}
		else {
			my %tdbentry ;
			next unless defined($colhds[$keys{'terrainCode'}]) ;
			my $tcode = $colhds[$keys{'terrainCode'}] ;
			if ($colhds[$keys{'selat'}] < $symin) { $symin = $colhds[$keys{'selat'}] ; }
			if ($colhds[$keys{'selong'}] > $sxmax) { $sxmax = $colhds[$keys{'selong'}] ; }
			if ($colhds[$keys{'nwlat'}] > $symax) { $symax = $colhds[$keys{'nwlat'}] ; }
			if ($colhds[$keys{'nwlong'}] < $sxmin) { $sxmin = $colhds[$keys{'nwlong'}] ; }
			next if ($tcode =~ /Unknown/i);
			$tdbentry{'terrainCode'} = $tcode ;
			$tdbentry{'selat'} = $colhds[$keys{'selat'}] ;
			$tdbentry{'selong'} = $colhds[$keys{'selong'}] ;
			$tdbentry{'nwlat'} = $colhds[$keys{'nwlat'}] ;
			$tdbentry{'nwlong'} = $colhds[$keys{'nwlong'}] ;
			$tdbentry{'county'} = $colhds[$keys{'county'}] ;
			my $cbgid = $colhds[$keys{'cbgid'}] ;
			$$tdb{$cbgid} = \%tdbentry ;
			$tdbentries++ ;
		}
	}
	print "$tdbentries loaded\n" ;
	close (FH) ;
	$$bbox[0] = $sxmin ;
	$$bbox[1] = $sxmax ;
	$$bbox[2] = $symin ;
	$$bbox[3] = $symax ;
	if ($tdbentries > 0) { return 1 ; } 
	else { return 0 ; }
}

sub printTerrainDB {
	my $fname = shift ;
	my $tdb = shift ;
	open (FH, ">", $fname) || die "Can't open $fname for writing:$!\n" ;
	print FH "CBG Id, County, SE Lat, SE Long, NW Lat, NW Long, TerrainCode\n" ;
	for my $tdbentry (keys %{$tdb}) {
		print "$tdbentry:" ;
		print Dumper $$tdb{$tdbentry} ;
		my @se = @{$$tdb{$tdbentry}{'SouthEast'}} ;
		my @nw = @{$$tdb{$tdbentry}{'NorthWest'}} ;
		print FH "$tdbentry, $$tdb{$tdbentry}{'county'}," ;
	       	printf FH "%.10g,%.10g,%.10g,%.10g,Unknown\n",
			$se[1],$se[0], $nw[1],$nw[0] ;
	}
	close(FH) ;
}
