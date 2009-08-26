#!/usr/bin/perl
use strict;
use warnings;

# require this file

sub test_contains {
    my ($iter,$shp_shape,$proj) = @_;
    unless ( defined $iter ) {
        fail( 'Iterator undefined' );
        return;
    }
    # Test that each "next" shape pixel is in fact in the shape
    my $fail = 0;
    my $total = 0;
    my $success;
    while ( defined(my $val = $iter->next) ) {
        my ($x,$y) = map { sprintf("%.6f",$_) } $iter->image->pix2proj( @{ $iter->current_coord } );
        if ( defined $proj ) {
            ($y,$x) = $proj->inverse($x,$y);
        }
        unless ( $shp_shape->contains_point(
                 Geo::ShapeFile::Point->new(X=>$x,Y=>$y)) ) {
            $fail++;
            warn "Failure at ($x,$y)";
        } 
        $total++;
    }
    $success = ($total - $fail) / $total;
    ok( $success >= 0.99, "Geo::ShapeFile::Shape contains agrees with iterator (" .
            sprintf("%.3f%%",$success * 100) . " success rate)" );

    # Reverse the buffer values and test the -1 values are in fact outside the shape
    my @old_buffer = @{$iter->buffer};
    my $evil_buffer;
    for my $i ( 0..@{$iter->buffer}-1 ) {
        for my $j ( 0..@{$iter->buffer->[$i]}-1 ) {
            $evil_buffer->[$i][$j] = $iter->buffer->[$i][$j] == -1 ? 1 : -1;
        }
    }
#    print Dumper(\@old_buffer), "\n", Dumper($evil_buffer),"\n";
    $iter->_reset;
    $iter->{buffer} = $evil_buffer;
    $fail = 0;
    $total = 0;
    while ( defined(my $val = $iter->next) ) {
        my ($x,$y) = map { sprintf("%.6f",$_) } $iter->image->pix2proj( @{ $iter->current_coord } );
        if ( defined $proj ) {
            ($y,$x) = $proj->inverse($x,$y);
        }
        unless ( ! $shp_shape->contains_point(
                 Geo::ShapeFile::Point->new(X=>$x,Y=>$y)) ) {
            $fail = 1;
            warn "Failure at ($x,$y)";
        } 
        $total++;
    }
    $success = ($total - $fail) / $total;
    ok( $success >= 0.99, "Geo::ShapeFile::Shape contains agrees with iterator (" .
            sprintf("%.3f%%",$success * 100) . " success rate)" );

    $iter->_reset;
    $iter->{buffer} = \@old_buffer;
}

1;
