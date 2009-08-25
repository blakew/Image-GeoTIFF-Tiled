package Geo::TiledTIFF::ShapePart;
use strict;
use warnings;
use Carp;

use vars qw/ $VERSION /;
$VERSION = '00.00.1';

# Parts are lines (start != end) or horizontal vertexes (start = end)

sub new {
    my ($class,@p) = @_;
    my $self = {};
    bless ($self,$class);
    my ($start,$end);
    
    if ( ref $p[0] and ref $p[0] eq 'ARRAY' and @p == 1 ) {
        croak "2-element array required during constructor."
            unless @{$p[0]} == 2;
        $start = $p[0]->[0];
        $end = $p[0]->[1];
    }
    elsif ( @p == 2 ) {
        $start = $p[0];
        $end = $p[1];
    }
    else {
        croak "Invalid constructor arguments: @p";
    }
    
    $self->start($start);
    $self->end($end);
    croak "Shape part needs a start and end point."
        unless defined $self->start and defined $self->end;
    
    return $self;
}

sub str {
    my $self = shift;
    my ($x0,$y0,$x1,$y1) = ( @{$self->start}[0..1], @{$self->end}[0..1] );
    return "line between ($x0, $y0) and ($x1, $y1)";
}

sub _point {
    my ($self,$key,$point) = @_;
    return $self->{$key} unless defined $point;
    confess "Point must be 2-element arrayref"
        unless ref $point and ref $point eq 'ARRAY' and scalar @{$point} == 2;
    carp "WARNING: Resetting $key value of part" if defined $self->{$key};
    confess "Point values must be defined" if grep { not defined $_ } @{$point};
#    confess "Point contains negative values" if grep { $_ < 0 } @$point;
    # Set the start/end point
    $self->{$key} = $point;
    
    my ($start,$end) = ( $self->{start}, $self->{end} );
    if ( defined $start and defined $end ) {
        # Ensure _upper at a lower latitude
        if ( $start->[1] > $end->[1] ) {
            $self->{_upper} = $end;
            $self->{_lower} = $start;
        }
        else {
            $self->{_upper} = $start;
            $self->{_lower} = $end;
        }
        # Reset and re-interpolate points if starting and ending point are now set
        $self->_reset_points;
    }
}
sub start { shift->_point('start',@_); }
sub end { shift->_point('end',@_); }
sub upper { return shift->{_upper} }
sub lower { return shift->{_lower} }

sub _reset_points {
    my ($self) = @_;
#    my ($start,$end) = ($self->start,$self->end);
    my ($x0,$y0,$x1,$y1) = ( @{$self->{_upper}}[0..1], @{$self->{_lower}}[0..1] );
    
    $self->{_points} = [];
#    $self->{_points}[0] = $x0;
#    $self->{_points}[int($y1 - $y0)] = $y0;
    
    return if $y0 == $y1;

    # Interpolate interemediate latitudes (given y, solve for x): 
    #   - interpolate the middle of the pixel
    my $y0_ =
        $y0 - int($y0) <= 0.5       # If in the lower half of the first pixel (inclusive)
            ? int($y0) + 0.5        # start interpolating the middle of that pixel
            : int($y0) + 1.5        # start interpolating the middle of the next pixel
    ;
    my $y1_ =
        $y1 - int($y1) < 0.5        # If in the lower half of the last pixel (exclusive)
            ? int($y1) - 0.5        # end interpolation in the middle of the previous pixel
            : int($y1) + 0.5        # end interpolating in the middle of that pixel
    ;
    
    #   x = x0 + (y - y0) * [ (x1 - x0)/(y1 - y0) ]
    my $factor = ($x1 - $x0) / ($y1 - $y0);
    my $i = 0;
    for ( my $y = $y0_; $y <= $y1_; $y++ ) {
#        my $i = $y - int($y0) + 0.5;
        $self->{_points}[$i++] = [ $x0 + ($y - $y0) * $factor, $y ];
    }
    $self->{_y0_} = $y0_;
#    $self->{_y1_} = $y1_;
}

sub get_point {
    # Get the [ x, y ] value of this part, given the integer y (latitude)
    my ($self,$y) = @_;
    croak "Require a y-value (latitude) to retrieve points." unless defined $y;
    return unless defined $self->{_y0_};
    my $i = int($y) + 0.5 - $self->{_y0_};
    if ( $i < 0 ) {
#        carp "Latitude $y smaller than first point",$self->{_y0_};
        return;
    }
    return $self->{_points}[$i];
#    return defined $r ? $r : [];
}

sub get_x {
    my ($self,$y) = @_;
    my $p = $self->get_point($y);
    return unless defined $p;
    return $p->[0];
}

#================================================================================================#
# POD
1;

=head1 NAME

Geo::TiledTIFF::ShapePart

=head1 DESCRIPTION

This class is used by Geo::TiledTIFF::Shape to represent a single "part" of a shape (a line between two points), shapes being made up of multiple parts.

Whenever the start or end points are set, the linear interpolation along integer y-values are calculated and stored. Interpolation is done at the middle of the pixel latitude.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=head3 new( $start, $end )

Starting and ending points are required during construction. As always, points are 2D array references [ $x, $y ].

=back

=head2 ACCESSORS

=over

=head3 start()

Returns, optionally sets, the starting point. Setting causes the intermediate points between the ending point to be re-interpolated and therefore shouldn't be done.

=head3 end()

Returns, optionally sets, the ending point. Setting causes the intermediate points between the starting point to be re-interpolated and therefore shouldn't be done.

=head3 upper()

Returns the start or end point, whichever has the lower latitude.

=head3 lower()

Returns the start or end point, whichever has the higher latitude.

=back

=head1 GET POINTS

=over

=head2 get_point($y)

Returns the [ $x, $y ] interpolated point located at (integer) pixel latitude $y, or C<undef> if there's no point along the given $y.

=head2 get_x($y)

Returns just the $x value of C<get_point>, or C<undef> if there's no point along the given $y.

=back

=head1 CONTACT

    Blake Willmarth
    blakew@wharton.upenn.edu
    215-573-7644

=cut



