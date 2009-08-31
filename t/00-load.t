#!/usr/bin/perl

use Test::More tests => 5;

BEGIN {
    use_ok( 'Module::Load' );
    use_ok( 'Image::GeoTIFF::Tiled::ShapePart' );
    use_ok( 'Image::GeoTIFF::Tiled::Shape' );
    use_ok( 'Image::GeoTIFF::Tiled::Iterator' );
    use_ok( 'Image::GeoTIFF::Tiled' );
}

diag( "Testing Image::GeoTIFF::Tiled $Image::GeoTIFF::Tiled::VERSION, Perl $], $^X" );
