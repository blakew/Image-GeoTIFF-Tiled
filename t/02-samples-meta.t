#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 14; 

eval { require Image::ExifTool; };
if($@) { print "1..1\nok 1\n"; warn "skipping, Image::ExifTool not available\n"; exit } 

use Image::GeoTIFF::Tiled;

for my $tiff (<./t/samples/usgs*.tif>) {
    my $exif = Image::ExifTool->new();
    $exif->ExtractInfo($tiff)
        or die $exif->GetValue('Error');
    my $image = Image::GeoTIFF::Tiled->new($tiff);
    is( 
        $image->file, 
        $tiff, 
        'Image file path' 
    );
    is( 
        $image->length, 
        $exif->GetValue('ImageHeight'), 
        'image length' 
    );
    is( 
        $image->width, 
        $exif->GetValue('ImageWidth'), 
        'image width' 
    );
    is( 
        $image->tile_length, 
        $exif->GetValue('TileLength'), 
        'tile length'
    );
    is( 
        $image->tile_width,
        $exif->GetValue('TileWidth'),
        'tile width'
    );
    is(
        $image->tile_size,
        $exif->GetValue('TileLength') * $exif->GetValue('TileWidth'),
        'tile size'
    );
    # relies on get_tile_pix
    is( 
        $image->tile_step, 
        $image->get_tile_pix( 0, $image->tile_length + 1 ), 
        'tile step' 
    );

}
