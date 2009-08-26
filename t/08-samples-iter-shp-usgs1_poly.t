#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 2; 

eval { require Geo::ShapeFile; };
if($@) { print "1..1\nok 1\n"; warn "skipping, Geo::ShapeFile not available\n"; exit } 
eval { require Geo::Proj4; };
if($@) { print "1..1\nok 1\n"; warn "skipping, Geo::Proj4 not available\n"; exit } 

require './t/test_contains.pl';     # Loads test_contains method
use lib 'lib';
use Geo::TiledTIFF;

#  Polygon in usgs1.tif that needs to be projected
#   - values: 4,5

my $image = Geo::TiledTIFF->new( "./t/samples/usgs1.tif" );
my $proj = Geo::Proj4->new( "+proj=utm +zone=17 +ellps=WGS84 +units=m" )
    or die "parameter error: ".Geo::Proj4->error. "\n";

my $shp = Geo::ShapeFile->new('./t/samples/usgs1_poly');
my $shp_shape = $shp->get_shp_record(1);
my $shape = 
    Geo::TiledTIFF::Shape->load_shape($image,$proj,$shp_shape);
my $iter = $image->get_iterator_shape($shape);

$iter->dump_buffer;

warn "Known diagreement with Geo::ShapeFile::Shape->contains_point at
(-78.2019736193844,41.05929317151) - manually checked, that point lies in the shape";
test_contains($iter,$shp_shape,$proj);
