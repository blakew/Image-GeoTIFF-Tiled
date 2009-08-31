#!/usr/bin/perl
use strict;
use warnings;
use Image::GeoTIFF::Tiled;
use Test::More tests => 2;

for my $tiff (<./t/samples/usgs*.tif>) {
#    print "Test image: $tiff\n";
    eval { Image::GeoTIFF::Tiled->new( $tiff ) };
    if ($@) {
        print $@;
    }
    ok( ! $@, "$tiff opened" );
}

