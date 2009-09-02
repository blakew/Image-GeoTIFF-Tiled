package Image::GeoTIFF::Tiled::Iterator;
use strict;
use warnings;
use Carp;

use Image::GeoTIFF::Tiled;

use vars qw/ $VERSION /;
$VERSION = '0.03';

#================================================================================================#
# Constructor

sub new {
    my ($class,$opts) = @_;
    my $self = {};
    bless ($self,$class);
    
    $self->_reset;
    # User-supplied options
    if ( $opts ) {
        for ( keys %{$opts} ) {
            $self->image($opts->{$_}) if $_ eq 'image';         # Image::GeoTIFF::Tiled object
            $self->boundary($opts->{$_}) if $_ eq 'boundary';   # (x_min,y_min,x_max,y_max)
            $self->{buffer} = $opts->{$_} if $_ eq 'buffer';    # 2D arrayref
        }
    }
    my $boundary = $self->boundary;
    $self->rows( int($boundary->[3]) - int($boundary->[1]) + 1 );         # pixel rows
    $self->cols( int($boundary->[2]) - int($boundary->[0]) + 1 );         # pixel columns
#    print "Iterator rows|cols: ",$self->rows,"|",$self->cols,"\n";
    $self->_verify;
    return $self;
}

sub _verify {
    my ($self) = @_;
    my ($image,$boundary,$buffer) = 
        ( $self->image, $self->boundary, $self->buffer );
    confess "Image::GeoTIFF::Tiled object required"
        unless defined $image and ref $image and $image->isa('Image::GeoTIFF::Tiled');
    confess "Boundary required"
        unless defined $boundary;
    confess "Array ref of size 4 required for boundary"
        unless ref $boundary and ref $boundary eq 'ARRAY'
        and scalar @{$boundary} == 4;
    confess "Buffered data required"
        unless defined $buffer;
    
        unless (ref $buffer and ref $buffer eq 'ARRAY'
        and ref $buffer->[0] and ref $buffer->[0] eq 'ARRAY') {
#             print Dumper $buffer;
             confess "Buffered data needs to be a 2D arrayref";
         }
    # Note: if rows,cols = 0 then just return undef
#    confess "No rows/cols; boundary needs to be (x_min,y_min,x_max,y_max) pixels."
#        unless $self->rows > 0 and $self->cols > 0;
}

sub _reset {
    my $self = shift;
    $self->current_row(0);
    $self->current_col(-1);
}

#================================================================================================#
# Accessors

sub _elem {
    my $self = shift;
    my $key = shift;
    return $self->{$key} unless @_;
    $self->{$key} = $_[0];
}
# Config accessors
sub image { &_elem(shift,'image', @_); }
sub boundary { &_elem(shift,'boundary', @_); }
#sub buffer { &_elem(shift,'buffer', @_); }
sub rows { &_elem(shift,'rows', @_); }
sub cols { &_elem(shift,'cols', @_); }
sub current_row { &_elem(shift,'current_row', @_); }
sub current_col { &_elem(shift,'current_col', @_); }
sub buffer { return shift->{buffer} }
sub get {
    my ($self,$row,$col) = @_;
    return $self->buffer->[$row][$col];
}

sub current_coord {
    my $self = shift;
    my $boundary = $self->{boundary};
    # current pixel position - middle of the pixel
    my $x = $boundary->[0] + $self->current_col + 0.5;
    my $y = $boundary->[1] + $self->current_row + 0.5;
    return [ $x, $y ];
}   

#================================================================================================#
# ITERATION METHODS

sub next {
    my ($self) = @_;
    my ($rows,$cols) = ($self->{rows},$self->{cols});
    my ($row,$col) = ($self->{current_row},$self->{current_col});
    my $val;
    NEXT_VAL: {
        # next buffer indices
        if ( $col == $cols - 1 ) {
            $row++;
            $col = 0;
        }
        else {
            $col++;
        }
        
        # Check if there is a "next" coordinate
        if ( $row >= $rows ||
            ( $row == $rows - 1 && $col >= $cols ) ) {
            return;
        }
        $val = $self->buffer->[$row][$col];
    # Return the next valid value
#    $val = $self->next while defined $val and $val == -1;
        redo NEXT_VAL if $val == -1;
    }
    # Store coordinate
    $self->{current_row} = $row;
    $self->{current_col} = $col;
    return $val;
}

#================================================================================================#
# DUMP

sub dump_buffer {
    my ($self) = @_;
    print "\nBuffer:\n";
    for my $r ( 0..$self->rows - 1 ) {
        for my $c ( 0..$self->cols - 1 ) {
            print " " if $c != 0;
            my $v = $self->buffer->[$r][$c];
            if ( $v == -1 ) {
                print '---';
            }
            else {
                printf( "%03i", $v );
            }
        }
        print "\n";
    }
}

#================================================================================================#
# POD
1;

=head1 NAME

Image::GeoTIFF::Tiled::Iterator - A convenience class to iterate through arbitrarily-shaped raster data.

=head1 SYNOPSIS

    use Image::GeoTIFF::Tiled;
    
    my $tiff = Image::GeoTIFF::Tiled->new( $tiff_filepath );
    my $iter = $tiff->get_iterator_pix( $px_min, $py_min, $px_max, $py_max );
    
    # Dump the buffered contents
    $iter->dump_buffer;
    
    while ( defined( my $val = $iter->next ) ) {
        printf "(%.3f,%.3f): %i\n", $tiff->pix2proj(@{$iter->current_coord}), $val;
        ... # do something based on the location, value
    }

=head1 DESCRIPTION

A convenience class to iterate through arbitrarily-shaped raster data. Returns some useful state information although there's room for additional features.

=head1 SUBROUTINES/METHODS

=head2 METHODS

=over

=item new(\%opts)

Where %opts must have the keys image, boundary, and buffer. Used by get_iterator_* methods.

=item image

The L<Image::GeoTIFF::Tiled> object.

=item boundary

The boundary of the buffer.

=item buffer

Returns the reference to the data buffer (a 2D array).

=item get($row,$col)

Gets the buffered value at row $row, column $col.

=item rows

The number of rows in the buffer.

=item cols

The number of columns in the buffer.

=item current_row

The current row corresponding to the last value passed by C<next>.

=item current_col

The current column corresponding to the last value passed by C<next>.

=item current_coord

Returns the [ $x, $y ] pixel coordinate corresponding to the last value returned by C<next>. The coordinate is placed in the middle of the pixel.

=item next

Returns the next buffer value, or undef if there are no further values.

=item dump_buffer

Pretty prints the buffer's values.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Blake Willmarth.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

