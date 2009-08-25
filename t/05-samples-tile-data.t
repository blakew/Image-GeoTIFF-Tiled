#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 6; 
use lib '../lib';
use Geo::TiledTIFF;

for my $tiff (<./samples/usgs*.tif>) {
    my $image = Geo::TiledTIFF->new($tiff);
    my $tile = $image->get_tile(0);
    my @test;
    for ( 0..$image->tile_size - 1 ) { 
        $test[$_] = ; 
    }
    is_deeply( $tile, \@test, 'Tile data' );

    @test = ( [ $tile ] );
    $tile = $image->get_tiles(0,0);
    is_deeply( $tile, \@test, '3D Tile data' );

    my ($ul,$ur,$bl,$br) = (50000,50001,50000 + $image->tile_step,50001 + $image->tile_step);
    my @tiles = ( 
        [ $image->get_tile($ul), $image->get_tile($ur) ],
        [ $image->get_tile($bl), $image->get_tile($br) ]
    );
    $tile = $image->get_tiles($ul,$br);
    is_deeply( $tile, \@tiles, '3D Tile data' );
#    for ($ul,$ur,$bl,$br) {
#        print "\nTile $_:\n";
#        $image->dump_tile($_);
#    }

}

