#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 120; 
use lib '../lib';
use Geo::TiledTIFF;

# Test tile, index functions

for my $tiff (<./samples/usgs*.tif>) {
    my $image = Geo::TiledTIFF->new($tiff);
    my $tw = $image->tile_width;
    my $tl = $image->tile_length;

    my @test = (
        # ($px,$py) <-> (tile,idx)
#        [ -1, 0, 0, 0 ],       # TODO: return undef when outside boundary;
#        TIFFComputeTile not well defined (says it returns valid values but
#        I'm not sure)
        [ 0, 0, 0, 0 ],
        [ 1, 0, 0, 1 ],
        [ 0, 1, 0, $tw ],
        [ 2, 2, 0, $tw * 2 + 2 ],
        [ $tw - 1, 0, 0, $tw - 1 ],
        [ $tw - 1, 2, 0, 2*$tw + $tw - 1 ],
        [ $tw, 0, 1, 0 ],
        [ 0, $tl, $image->tile_step, 0 ],
        [ $tw, $tl, $image->tile_step + 1, 0 ],
        [ $tw - 1, $tl - 1, 0, $tw * $tl - 1 ]
    );

    for ( @test ) {
        my ($px,$py) = ($_->[0],$_->[1]);
        my $t = $image->get_tile_pix($px,$py);
        is( $t, $_->[2], "($px,$py) tile number: $t" );
        my $i = $image->get_pix_idx($px,$py);
        is( $i, $_->[3], "($px,$py) index into tile: $i" );
        my ($x,$y) = $image->get_pix_tile( $t, $i );
        is( $x, $px, "x pixel get coordinate of tile ($t) + index ($i)" );
        is( $y, $py, "y pixel get coordinate of tile ($t) + index ($i)" );
        ($x,$y) = (0,0);
        $image->set_pix_tile( $t, $i, $x, $y );
        is( $x, $px, "x pixel get coordinate of tile ($t) + index ($i)" );
        is( $y, $py, "y pixel get coordinate of tile ($t) + index ($i)" );
    }
}
