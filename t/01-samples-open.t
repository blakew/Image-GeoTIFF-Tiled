#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use Geo::TiledTIFF;
use Test::More tests => 2;

for my $tiff (<./t/samples/usgs*.tif>) {
#    print "Test image: $tiff\n";
    eval { Geo::TiledTIFF->new( $tiff ) };
    if ($@) {
        print $@;
    }
    ok( ! $@, "$tiff opened" );
}

