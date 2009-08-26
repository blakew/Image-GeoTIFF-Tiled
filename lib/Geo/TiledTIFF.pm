package Geo::TiledTIFF;
use strict;
use warnings;
use Carp;
use Geo::TiledTIFF::Image;
use Geo::TiledTIFF::Iterator;
use Geo::TiledTIFF::Shape;

use vars qw( $VERSION @ISA );
$VERSION = '0.01';

#use base 'Geo::TiledTIFF::Image';
push @ISA, 'Geo::TiledTIFF::Image';

#sub new {
#    my ($class,$file) = @_;
#    my $image = Geo::TiledTIFF::Image->new($file);
#    return bless( { image => $image }, $class );  
#}
#
#sub get_image { return shift->{image}; }

sub _constrain_boundary {
    my ($self,$px_bound) = @_;
    
    # Round to nearest int
    for (0..1) { $px_bound->[$_] = sprintf("%.0f",$px_bound->[$_]+.00001); }
#    for (2..3) { $px_bound->[$_] = sprintf("%.0f",$px_bound->[$_]+.00001); }
    for (2..3) { $px_bound->[$_] = int($px_bound->[$_]); }
    
    # Check if it's completely outside the image
    if ( 
            $px_bound->[0] >= $self->width      # min_x to the right
         || $px_bound->[1] >= $self->length     # min_y below
         || $px_bound->[2] < 0                  # max_x to the left
         || $px_bound->[3] < 0 ) {              # max_y above
        return 0;
    }
    
    # x_min
    $px_bound->[0] = 0 if $px_bound->[0] < 0;
    # y_min        
    $px_bound->[1] = 0 if $px_bound->[1] < 0;
    # x_max
    $px_bound->[2] = $self->width - 1 if $px_bound->[2] >= $self->width;
    # y_max    
    $px_bound->[3] = $self->length - 1 if $px_bound->[3] >= $self->length;
    
    # Check if the dimensions no longer make sense
    if ( 
            $px_bound->[0] > $px_bound->[2]
        ||  $px_bound->[1] > $px_bound->[3] ) {
        return 0;
    }    
    
    1;
}

sub get_iterator_shape {
    my ($self,$shape) = @_;
    croak "Need a Geo::TiledTIFF::Shape object" 
        unless ref $shape and $shape->isa('Geo::TiledTIFF::Shape');
    my @px_bound = ( $shape->boundary );
    unless ( $self->_constrain_boundary(\@px_bound) ) {
        return;
    }
#    print "Extracting data from (@px_bound)...\n";
    my $data = $self->extract_2D_array(@px_bound,$shape);
    return Geo::TiledTIFF::Iterator->new({
        image => $self,
        boundary => \@px_bound,
        buffer => $data
    });
}

sub get_iterator_pix {
    my ($self,@px_bound) = @_;
    unless ( $self->_constrain_boundary(\@px_bound) ) {
        carp "Boundary outside of image";
        return;
    }
    my $data = $self->extract_2D_array(@px_bound,undef);
    return Geo::TiledTIFF::Iterator->new({
        image => $self,
        boundary => \@px_bound,
        buffer => $data
    });
}

sub dump_tile {
	my ($self,$tile) = @_;
	croak "No tile specified" unless defined $tile;
	my $buffer = $self->get_tile($tile);
	local $| = 1;
    for ( 0 .. $self->tile_size - 1 ) {
        printf("%03i", $buffer->[$_]);
        if ( ($_ + 1) % ($self->tile_width) == 0) {
            print("\n");
		}
        else {
            print(" ");
		}
    }
}

#sub _get_x_perl {
#    my ($shape,$y) = @_;
#    croak "Need a Geo::TiledTIFF::Shape object" unless
#            $shape->isa('Geo::TiledTIFF::Shape');
#    return $shape->get_x($y);
#}

#=head3 $t->proj2pix_boundary_m($x_min,$y_min,$x_max,$y_max)
#
#Transforms the given projection rectangular boundary to its corresponding pixel boundary (mutative).
#
#=head3 $t->proj2pix_boundary($x_min,$y_min,$x_max,$y_max)
#
#Transforms the given projection rectangular boundary, returning its corresponding pixel boundary as a list.
#

#sub proj2pix_boundary_m {
#    my ($self,@px_bound) = @_;
#    $self->proj2pix_m($px_bound[0],$px_bound[1]);
#    $self->proj2pix_m($px_bound[2],$px_bound[3]);
#}

#sub proj2pix_boundary {
#    my ($self,@px_bound) = @_;
#    return (
#        $self->proj2pix($px_bound[0],$px_bound[1]),
#        $self->proj2pix($px_bound[2],$px_bound[3])
#    );
#}

1;

