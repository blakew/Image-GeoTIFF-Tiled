#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 20; 
use Image::GeoTIFF::Tiled;

# Test projected <-> pixel translations
my $exp = {
    # Found using listgeo utility
    './t/samples/usgs1.tif' => {
        upper_left => [ '730232.510', 4557035.327 ],
        lower_left => [ '730232.510', 4540490.783 ],
        upper_right => [ 742478.155, 4557035.327 ],
        lower_right => [ 742478.155, 4540490.783 ],
        center => [ 736355.333, 4548763.055 ]
    },
    './t/samples/usgs2.tif' => {
        upper_left => [ 698753.305, 4556059.506 ],
        lower_left => [ 698753.305, 4539568.607 ],
        upper_right => [ 710925.798, 4556059.506 ],
        lower_right => [ 710925.798, 4539568.607 ],
        center => [ 704839.551, 4547814.057 ]
    },
};

for my $tiff (<./t/samples/usgs*.tif>) {
    my $image = Image::GeoTIFF::Tiled->new($tiff);
    my $w = $image->width;
    my $l = $image->length;
    my %lookup = (
        upper_left => [ 0, 0 ],
        lower_left => [ 0, $l ],
        upper_right => [ $w, 0 ],
        lower_right => [ $w, $l ],
        center => [ $w / 2, $l / 2 ]
    );
    for my $loc ( keys %lookup ) {
        my $coord = [ map { sprintf("%.1f",$_) } @{$lookup{$loc}} ];
        # Project
        my $got = [ map { sprintf("%.3f",$_) } $image->pix2proj($coord->[0],$coord->[1]) ];
        is_deeply( $got, $exp->{$tiff}{$loc}, "$tiff: $loc projection" );
        # Back to pixels
        $got = [ map { my $n = sprintf("%.1f",$_); $n != 0 ? $n : '0.0' } $image->proj2pix(@$got) ];
        is_deeply( $got, $coord, "$tiff: $loc pixels" );
    }
}
