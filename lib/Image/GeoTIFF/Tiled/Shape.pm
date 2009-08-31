package Image::GeoTIFF::Tiled::Shape;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(minmax);
use Module::Load;

use Image::GeoTIFF::Tiled;
use Image::GeoTIFF::Tiled::ShapePart;

# Needs to be a series of ordered pixel points

# Data structure: 2D array - one row per pixel row
#   - first row ($data->[0]) is at pixel latitude y_min
#   - last row is at pixel latitude y_max
#   - rows should be ordered on longitude (x) (specific method call when using main method)

use vars qw/ $VERSION /;
$VERSION = '0.01';

#================================================================================================#

sub new {
    my ($class,$opts) = @_;
    my $self = {};
    bless ($self,$class);
    
    if ( ref $opts eq 'ARRAY' ) {
        croak "Need x_min, y_min, x_max, y_max elements."
            unless scalar @$opts == 4;
        $self->x_min($opts->[0]);
        $self->y_min($opts->[1]);
        $self->x_max($opts->[2]);
        $self->y_max($opts->[3]);
    }
    elsif ( ref $opts eq 'HASH' ) {
        for ( keys %{$opts} ) {
            $self->x_min($opts->{$_}) if $_ eq 'x_min';
            $self->y_min($opts->{$_}) if $_ eq 'y_min';
            $self->x_max($opts->{$_}) if $_ eq 'x_max';
            $self->y_max($opts->{$_}) if $_ eq 'y_max';
        }
    }
    croak "Boundary required." unless grep { defined $_ } $self->boundary;
    return $self;
}

sub load_shape {
    my ($class,$tiff,$proj,$shape) = @_;
    croak "loading shapes must be done by the class." if ref $class;
#    croak "Geo::Projection required." unless defined $proj and ref $proj and $proj->isa("Geo::Projection");
    croak "Image::GeoTIFF::Tiled required." unless defined $tiff and ref $tiff and $tiff->isa("Image::GeoTIFF::Tiled");
    if ( defined $proj ) {
        croak "Geo::Proj4 required." unless ref $proj and $proj->isa("Geo::Proj4");
        load 'Geo::Proj4';
    } 
    my $self;
    if ( ref $shape and $shape->isa('Geo::ShapeFile::Shape') ) {
        load 'Geo::ShapeFile';  # run-time loading
        my $boundary = [ 
            $shape->x_min,
            $shape->y_min,
            $shape->x_max,
            $shape->y_max
        ];
#        $proj->project_boundary_m(@$boundary);
        Image::GeoTIFF::Tiled::Shape->project_boundary($proj,$boundary)
                if defined $proj;
        $self = Image::GeoTIFF::Tiled::Shape->new(
            [ $tiff->proj2pix_boundary(@$boundary) ]
        );
        for my $i ( 1..$shape->num_parts ) {
            for ( $shape->get_part($i) ) {
#                my ($x,$y) = $tiff->proj2pix($proj->project($_->X,$_->Y));
                my ($x,$y) = 
                        defined $proj 
                            ? ($proj->forward($_->Y,$_->X))
                            : ($_->X,$_->Y); 
                $self->add_point($tiff->proj2pix($x,$y));
            }
        }
    }
    else {
        croak "Cannot load unknown shape";
    }
    return $self;
}

sub project_boundary {
    my ($class,$proj,$b) = @_;
#    my @points = (
#        [ $b->[0], $b->[3] ],
#        [ $b->[0], $b->[1] ],
#        [ $b->[2], $b->[3] ],
#        [ $b->[2], $b->[1] ]
#    );
    my @px = ( $b->[0], $b->[0], $b->[2], $b->[2] );
    my @py = ( $b->[3], $b->[1], $b->[3], $b->[1] );
    for ( 0..3 ) {
         # See Geo::Proj4 documentation - this is correct
        ( $px[$_], $py[$_] ) = $proj->forward( $py[$_], $px[$_] );
    } 
    ($b->[0],$b->[2]) = minmax( @px );
    ($b->[1],$b->[3]) = minmax( @py );
}

#================================================================================================#

sub _elem {
    my $self = shift;
    my $key = shift;
    return $self->{"_$key"} unless @_;
    $self->{"_$key"} = $_[0];
}
# Config accessors
sub x_min { &_elem(shift,'x_min', @_); }
sub y_min { &_elem(shift,'y_min', @_); }
sub x_max { &_elem(shift,'x_max', @_); }
sub y_max { &_elem(shift,'y_max', @_); }
sub boundary {
    my ($self) = @_;
    return (
        $self->x_min,
        $self->y_min,
        $self->x_max,
        $self->y_max
    );
}
sub corners {
    my ($self) = @_;
    return (
        [ $self->x_min, $self->y_min ],
        [ $self->x_min, $self->y_max ],
        [ $self->x_max, $self->y_min ],
        [ $self->x_max, $self->y_max ]
    );
}

#================================================================================================#

sub add_point {
    my ($self,$x,$y) = @_;
    my $point = [ $x, $y ];
#    print "adding point: ($x,$y)\n";
    my $last_start = $self->{_last_start};
    my $last_end = $self->{_last_end};
    
    # First point
    unless ( defined $self->{_first_point} ) {
        $self->{_first_point} = $point;
        $self->{_last_end} = $point;
        return;
    }
    
    # TEST IF $LAST_END IS A LOCAL HORIZONTAL VERTEX - IF SO ADD THE POINT AGAIN
    if ( defined $last_start
            and &_local_hvertex($last_start,$last_end,$point) ) {
        push @{$self->{_parts}}, 
            Image::GeoTIFF::Tiled::ShapePart->new( $last_end, $last_end );
    }
    
    # Add a new part
    push @{$self->{_parts}}, 
        Image::GeoTIFF::Tiled::ShapePart->new( $last_end, $point );
    
    # Last point (if equals first point) - test if it's a local horizontal vertex (only chance)
    if ( $self->{_first_point}[0] == $x
         and
         $self->{_first_point}[1] == $y
         and
         &_local_hvertex( $last_end, $point, $self->get_part(0)->end )
         ) {
             push @{$self->{_parts}}, 
                Image::GeoTIFF::Tiled::ShapePart->new( $point, $point );
    }
    $self->{_last_start} = $last_end;
    $self->{_last_end} = $point;
}

sub _local_hvertex {
    # Test $p2
    my ($p1,$p2,$p3) = @_;
    return 1 if
        ( $p2->[1] < $p1->[1] && $p2->[1] < $p3->[1] )
            or
        ( $p2->[1] > $p1->[1] && $p2->[1] > $p3->[1] );
    0;
}

sub as_array {
    my ($self) = @_;
    my @a;
    for ( 0..$self->num_parts-1 ) {
        my $p = $self->get_part($_);
        push @a, [ $p->start, $p->end ];
    }
    \@a;
}   

#================================================================================================#

sub num_parts {
    my ($self) = @_;
    return defined $self->{_parts} ? scalar @{$self->{_parts}} : 0;
}

sub get_part {
    my ($self,$i) = @_;
    return $self->{_parts}[$i];
}

sub get_x {
    # Retrieves all x-values|points along integer latitude y
    my ($self,$y) = @_;
    my @parts;
#    local $| = 1; print "Getting x_values for $y: ";
    for ( 0..$self->num_parts - 1 ) {
        my $part = $self->get_part($_);
        push @parts, $part
            if $y >= $part->upper->[1] and $y <= $part->lower->[1];
    }
    # @parts now has all parts of the shape containing $y
#    my @points =
    my @x = 
#     return
        sort 
#                    { $a->[0] <=> $b->[0] }    # point sorting
            map { $_->get_x($y) } @parts;
#    print "(",join (', ',map { sprintf("%.2f",$_) } @x),")\n";
    return \@x;
}

# - NOTE: IF TWO EQUAL X VALUES ARE OBTAINED, ITS A LOCAL HORIZONTAL VERTEX AND SHOULDN'T CHANGE THE
#   INSIDE/OUTSIDE STATE (or should be changed twice - resulting in the same state AFTER the point is checked)

#================================================================================================#
# POD
1;

=head1 NAME

Image::GeoTIFF::Tiled::Shape

=head1 SYNOPSIS

    use Image::GeoTIFF::Tiled;
    
    # Initiate an instance via a class factory method, importing a pre-existing shape object:
    use Geo::ShapeFile;
    my $shp_shape = ... # A Geo::ShapeFile::Shape retrieved from Geo::ShapeFile methods
    my $shape = Image::GeoTIFF::Tiled::Shape->load_shape( $tiff, $proj, $shp_shape );
    
    # OR Create your own:
    my $shape = Image::GeoTIFF::Tiled::Shape->new({
        x_min => ...,
        y_min => ...,
        x_max => ...,
        y_max => ...
    });
    $shape->add_point($x,$y) for ...;
    
    # Initiate the TIFF image object
    my $t = Image::GeoTIFF::Tiled->new( $tiff );
    
    # Get in iterator for the pixels in the shape
    my $iter = $t->get_iterator( $shape );
    
=head1 DESCRIPTION

This class is meant to be used in conjuction with Image::GeoTIFF::Tiled in order to easily iterate over image pixels contained in an arbitrary shape. It does so by linking Image::GeoTIFF::Tiled::ShapePart's, which are essentially lines between two points, with all intermediate points along integer y-values interpolated.

Objects should be instantiated via the C<load_shape> method for pre-defined shape-like objects (L<Geo::ShapeFile::Shape> being an example). Otherwise they must be instantiated with a boundary, and points should be added sequentially.

Other than constructing a useful data structure for getting an iterator, there isn't any other stated purpose for this class.

All coordinates must be in pixels.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new( \%boundary )

=item new( \@boundary )

where %boundary has the x_min, y_min, x_max, and y_max keys filled or @boundary has them in that order. Pixel coordinates required. Without defining a boundary the constructor throws an exception.

=back

=head2 FACTORY METHOD

=over

=item load_shape( $tiff, $proj, $shape )

Loads a pre-defined shape object defined by an external class. Currently only loads L<Geo::ShapeFile::Shape> objects. 

Geo::Proj4 and Image::GeoTIFF::Tiled objects must be pre-loaded into the class before calling this method, unless the shape is already projected, in which case pass undef as the $proj parameter.

=back

=head2 METHODS

=over

=item x_min x_max y_min y_max

Retrieves the boundary values.

=item boundary

Equivalent to (C<$shape-&gt;x_min>, C<$shape-&gt;y_min>, C<$shape-&gt;x_max>, C<$shape-&gt;y_max>).

=item corners

Returns a list of four two-element arrayref's containing the upper left, lower left, upper right, and lower right corner coordinates, in that order.

=item num_parts

Returns the number of Image::GeoTIFF::Tiled::ShapePart's in this shape.

=item get_part($i)

Returns the ith Image::GeoTIFF::Tiled::ShapePart in this shape.

=item as_array

Returns a 2D array reference of [ start, end ] points corresponding to each part of the shape.

=item add_point($x,$y)

Adds the ($x,$y) point to this shape. Only used for making custom shapes.

=item project_boundary($proj,$b)

Class method. Returns the projected boundary using projection (Geo::Proj4) $proj and boundary $b, a 4-element array ref with x_min, y_min, x_max, y_max as values.

=item get_x($y)

Returns a reference to a sorted array containing all x-pixel values along the integer y latitude. This method is used to determine if a given pixel lies inside the shape by implementing a ray-casting algorithm using a state machine (either OUTSIDE or INSIDE).

Repeated values indicate a local horizontal vertex.

=back

=head1 SEE ALSO

Geo::Proj4, Image::GeoTIFF::Tiled, Image::GeoTIFF::Tiled::Iterator, Image::GeoTIFF::Tiled::ShapePart, L<Geo::ShapeFile>

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


