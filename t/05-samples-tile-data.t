#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 6; 
use Image::GeoTIFF::Tiled;

for my $tiff (<./t/samples/usgs*.tif>) {
    my $image = Image::GeoTIFF::Tiled->new($tiff);
    my $tile = $image->get_tile(0);
#    $image->dump_tile(0);
    my $ok = 1;
    for my $v ( @$tile ) {
        $ok = 0 unless grep { $v == $_ } qw/ 0 1 4 /;
    }
    ok( $ok, 'First tile' );

    my @test = ( [ $tile ] );
    $tile = $image->get_tiles(0,0);
    is_deeply( $tile, \@test, '3D Tile data' );

    my $tile_no = 122;
    my ($ul,$ur,$bl,$br) = ($tile_no,$tile_no + 1,$tile_no + $image->tile_step,$tile_no + 1 + $image->tile_step);
#    print "Tiles: $ul, $ur, $bl, $br\n";
    my @tiles = ( 
        [ $image->get_tile($ul), $image->get_tile($ur) ],
        [ $image->get_tile($bl), $image->get_tile($br) ]
    );
    $tile = $image->get_tiles($ul,$br);
    is_deeply( $tile, \@tiles, '3D Tile data' );
}

