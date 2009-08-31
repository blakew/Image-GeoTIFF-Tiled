package Image::GeoTIFF::Tiled;
use strict;
use warnings;
use Carp;
use Image::GeoTIFF::Tiled::Iterator;
use Image::GeoTIFF::Tiled::Shape;

use vars qw( $VERSION );
$VERSION = '0.01';

use Inline C => Config => 
             INC => '-I/usr/include/geotiff',
             LIBS => '-ltiff -lgeotiff'
#             AUTO_INCLUDE => '#include <tiff.h>',
#             AUTO_INCLUDE => '#include <geotiff.h>',
#             AUTO_INCLUDE => '#include <xtiffio.h>' 
            ;

use Inline C => 'DATA',
#    VERSION => '0.01',
    NAME => 'Image::GeoTIFF::Tiled'; 

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
    croak "Need a Image::GeoTIFF::Tiled::Shape object" 
        unless ref $shape and $shape->isa('Image::GeoTIFF::Tiled::Shape');
    my @px_bound = ( $shape->boundary );
    unless ( $self->_constrain_boundary(\@px_bound) ) {
        return;
    }
#    print "Extracting data from (@px_bound)...\n";
    my $data = $self->extract_2D_array(@px_bound,$shape);
    return Image::GeoTIFF::Tiled::Iterator->new({
        image => $self,
        boundary => \@px_bound,
        buffer => $data
    });
}

sub get_iterator_pix {
    my ($self,@px_bound) = @_;
    unless ( $self->_constrain_boundary(\@px_bound) ) {
#        carp "Boundary outside of image";
        return;
    }
    my $data = $self->extract_2D_array(@px_bound,undef);
    return Image::GeoTIFF::Tiled::Iterator->new({
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

__DATA__

__C__

#include <tiff.h>
#include <geotiff.h>
#include <xtiffio.h>

#define DEBUG 0

typedef struct {
    const char *file;       // Filename
    TIFF *xtif;             // TIFF image handle
    GTIF *gtif;             // GeoTIFF image handle
    uint32 length, width;   // Image length, width in pixels
    uint32 tile_length, tile_width;
                            // Tile length, width in pixels
    tsize_t tile_size;      // Tile size (bytes)
    int tile_step;          // # of tiles per row
} Image;

static void _center_pixel(double * x, double * y);
static void _verify_image(Image*);
static void _read_meta(Image*);
static void _print_meta(Image*);
static int _get_state(int,double,double*,double*,int,int*);
//static int _constrain_boundary(Image*,int*);
    
//--------------------------------------------------------------------------------------------------
// COORDINATE-PIXEL TRANSFORMATIONS

static void _center_pixel(double * x, double * y) {
    *x = (int)*x + 0.5;
    *y = (int)*y + 0.5;
}

void center_pixel(SV* obj, SV* svx, SV* svy) {
    double x = (double)SvNV(svx);
    double y = (double)SvNV(svy);
    _center_pixel(&x,&y);
    sv_setnv(svx,x);
    sv_setnv(svy,y);
}

void proj2pix_m(SV* obj, SV* svx, SV* svy) {
    // Convert projected coordinates to pixel coordinates (geotiff operation) - MUTATIVE
    Image* image = (Image*)SvIV(SvRV(obj));
    double x = (double)SvNV(svx);
    double y = (double)SvNV(svy);
    
    if ( DEBUG == 2 )
        printf("(proj2pix_m)Converting projected coordinates (%.2f,%.2f) to pixel coordinates: ",x,y);
    
    if ( GTIFPCSToImage(image->gtif, &x, &y) == 0 )
        croak("\n(proj2pix_m)Could not convert geo-coordinates to pixel coordinates.\n");
    
    if ( DEBUG == 2 )
        printf("(%.1f,%.1f)\n",x,y);
    
    sv_setnv(svx,x);
    sv_setnv(svy,y);
}

void proj2pix(SV* obj, SV* svx, SV* svy) {
    // Convert projected coordinates to pixel coordinates (geotiff operation) - TRANSFORMATIVE
    Inline_Stack_Vars;
    SV* svx_cp = sv_mortalcopy(svx);
    SV* svy_cp = sv_mortalcopy(svy);
    
    // Do the mutative operation
    proj2pix_m( obj, svx_cp, svy_cp );
    
    // Push the values of svx_cp, svy_cp onto the stack and return them
    Inline_Stack_Reset;
    Inline_Stack_Push(svx_cp);
    Inline_Stack_Push(svy_cp);
    Inline_Stack_Done;
}

void pix2proj_m(SV* obj, SV* svx, SV* svy) {
    // Convert pixel coordinates to projected coordinates (geotiff operation) - MUTATIVE
    Image* image = (Image*)SvIV(SvRV(obj));
    double x = (double)SvNV(svx);
    double y = (double)SvNV(svy);
    
    if ( DEBUG == 2 )
        printf("(pix2proj_m)Converting pixel coordinates (%.1f,%.1f) to projected coordinates: ",x,y);
    
    if ( GTIFImageToPCS(image->gtif, &x, &y) == 0 )
        croak("\n(pix2proj_m)Could not convert pixel coordinates to geo-coordinates.\n");
    
    if ( DEBUG == 2 )
        printf("(%.2f,%.2f)\n",x,y);
        
    sv_setnv(svx,x);
    sv_setnv(svy,y);
}

void pix2proj(SV* obj, SV* svx, SV* svy) {
    // Convert pixel coordinates to projected coordinates (geotiff operation) - TRANSFORMATIVE
    Inline_Stack_Vars;
    SV* svx_cp = sv_mortalcopy(svx);
    SV* svy_cp = sv_mortalcopy(svy);
    
    // Do the mutative operation
    pix2proj_m( obj, svx_cp, svy_cp );
    
    // Push the values of svx_cp, svy_cp onto the stack and return them
    Inline_Stack_Reset;
    Inline_Stack_Push(svx_cp);
    Inline_Stack_Push(svy_cp);
    Inline_Stack_Done;
}

void proj2pix_boundary_m(SV* obj, SV* svx_min, SV* svy_min, SV* svx_max, SV* svy_max) {
    if ( (double)SvNV(svx_min) > (double)SvNV(svx_max) )
        croak("min X/lon > max X/lon");
    if ( (double)SvNV(svy_min) > (double)SvNV(svy_max) )
        croak("min Y/lat > max Y/lat");
    proj2pix_m(obj,svx_min,svy_max);
    proj2pix_m(obj,svx_max,svy_min);
}

void proj2pix_boundary(SV* obj, SV* svx_min, SV* svy_min, SV* svx_max, SV* svy_max) {
    Inline_Stack_Vars;
    SV* svx_min_cp = sv_mortalcopy(svx_min);
    SV* svy_min_cp = sv_mortalcopy(svy_min);
    SV* svx_max_cp = sv_mortalcopy(svx_max);
    SV* svy_max_cp = sv_mortalcopy(svy_max);
    proj2pix_boundary_m(obj,svx_min_cp,svy_min_cp,svx_max_cp,svy_max_cp);
    Inline_Stack_Reset;
    Inline_Stack_Push(svx_min_cp);
    Inline_Stack_Push(svy_max_cp);
//    Inline_Stack_Push(svy_min_cp);
    Inline_Stack_Push(svx_max_cp);
//    Inline_Stack_Push(svy_max_cp);
    Inline_Stack_Push(svy_min_cp);
    Inline_Stack_Done;
}

//--------------------------------------------------------------------------------------------------
// IMAGE UTILITY

static void _verify_image(Image* image) {
    // Check that it is of a type that we support - if not throw errors
    uint16 bps, spp;
    if ( (TIFFGetField(image->xtif, TIFFTAG_BITSPERSAMPLE, &bps) == 0) || (bps != 8) )
        croak("Either undefined or unsupported number of bits per sample.");
    if ( (TIFFGetField(image->xtif, TIFFTAG_SAMPLESPERPIXEL, &spp) == 0) || (spp != 1) )
        croak("Either undefined or unsupported number of samples per pixel.");
    // TODO: relax this condition?
    if ( TIFFIsTiled(image->xtif) == 0 )
        croak("Image must be tiled.");
}

static void _read_meta(Image* image) {
    uint32 width0, length0;
    uint32 width1, length1;
    uint32 tilebyte0;
    uint32 tilebyte;
    
    TIFFGetField(image->xtif,TIFFTAG_IMAGELENGTH,&length0);
    TIFFGetField(image->xtif,TIFFTAG_IMAGELENGTH,&length1);
    TIFFGetField(image->xtif,TIFFTAG_IMAGEWIDTH,&width0);
    TIFFGetField(image->xtif,TIFFTAG_IMAGEWIDTH,&width1);
    image->length = length0;
    image->width = width0;
    TIFFGetField(image->xtif,TIFFTAG_TILEBYTECOUNTS,&tilebyte0);
    TIFFGetField(image->xtif,TIFFTAG_TILEBYTECOUNTS,&tilebyte);
    TIFFGetField( image->xtif,TIFFTAG_TILELENGTH,&(image->tile_length) );
    TIFFGetField( image->xtif,TIFFTAG_TILEWIDTH,&(image->tile_width) );
    image->tile_size = TIFFTileSize(image->xtif) * sizeof(char);
    image->tile_step = 
        TIFFComputeTile( image->xtif, 0, image->tile_length, 0, 0 );
    if ( DEBUG >= 1 )
        _print_meta(image);
}

static void _print_meta(Image* image) {
//  printf("\n");
    printf("Image length x width: %i x %i\n",image->length,image->width);
    printf("Tiles in image: %d\n",TIFFNumberOfTiles(image->xtif));
    printf("Tile length x width: %d x %d\n",image->tile_length,image->tile_width);
    printf("Tile row size (bytes): %d\n",TIFFTileRowSize(image->xtif));
    printf("Tile size: %d\n",image->tile_size);
    printf("Tile # at pixel (0,%d): %d\n",image->tile_length,image->tile_step);
    printf("\n");
}

void print_meta(SV* obj) {
    Image* image = (Image*)SvIV(SvRV(obj));
    _print_meta(image);
}

//--------------------------------------------------------------------------------------------------
// TILE

int get_tile_pix(SV* obj, double x, double y) {
    // Computes the tile # corresonding to a given pixel coordinates
    int tile;
    Image* image = (Image*)SvIV(SvRV(obj));
    
    if ( DEBUG == 2 )
        printf( "Getting tile # for pixel coordinates (%.f,%.f): ", x, y );
        
    // Get the tile #
    tile = TIFFComputeTile( image->xtif, x, y, 0, 0 );
    
    if ( DEBUG == 2 )
        printf("%d\n",tile);
    
    return tile;
}

void set_pix_tile(SV* obj, int tile, int i, SV* svx, SV* svy) {
    // Given a tile # and index, calculate pixel coordinates (MUTATIVE)
    Image* image = (Image*)SvIV(SvRV(obj));
    double x = (double)SvNV(svx);
    double y = (double)SvNV(svy);
    int tile_lat = tile / image->tile_step;
    int tile_lon = tile % image->tile_step;
    
    // (tile_lon,tile_lat) -> tile location in tile grid
    if ( DEBUG == 2 )
        printf("\tTile coordinates: (%d,%d)\n",tile_lon,tile_lat);
    
    // Now get tile[i] location in pixel grid
    x = (double)(tile_lon * image->tile_width + i % image->tile_width);
    y = (double)(tile_lat * image->tile_length + (int)i / image->tile_length);
    
    if ( DEBUG == 2 )
        printf("\tPixel coordinates (%.f,%.f)\n",x,y);
    
    sv_setnv(svx,x);
    sv_setnv(svy,y);    
}

void get_pix_tile(SV* obj, int tile, int i) {
    // Given a tile # and index, calculate pixel coordinates (TRANSFORMATIVE)
    Inline_Stack_Vars;
    SV* svx = newSVnv( (double)0 );
    SV* svy = newSVnv( (double)0 );
    
    // Do the mutative operation
    set_pix_tile( obj, tile, i, svx, svy );
    
    // Push the values of svx, svy onto the stack and return them
    Inline_Stack_Reset;
    Inline_Stack_Push(sv_2mortal(svx));
    Inline_Stack_Push(sv_2mortal(svy));
    Inline_Stack_Done;
}

// Given pixel coordinates, calculate the index into its tile
int get_pix_idx(SV* obj, double dpx, double dpy) {
    Image* image = (Image*)SvIV(SvRV(obj));
    int px = (int)dpx;
    int py = (int)dpy;
    int idx_row = ( py - (py / image->tile_length) * image->tile_length ) * image->tile_length;
                                                            // first pixel index in the UL tile row (tile[y_min][0])
    return idx_row + (px % image->tile_width);
                                                            // UL boundary pixel index (tile[y_min][x_min])
}

//--------------------------------------------------------------------------------------------------
// DATA

SV* get_tile(SV* obj, int tile) {
    Image* image;
    uint32 i;
    SV* buffer;
	image = (Image*)SvIV(SvRV(obj));
	// Read in char* buffer
	buffer = newSV(image->tile_size);

//    if ( TIFFReadRawTile( image->xtif, tile, (char *)SvPVX(buffer), image->tile_size ) == -1 )
    if ( TIFFReadEncodedTile( image->xtif, tile, (char *)SvPVX(buffer), image->tile_size ) == -1 )
        croak("Read error on tile.");

    // Copy buffer into array
    AV* array = newAV();
    av_extend( array, image->tile_size - 1 );
	for ( i = 0; i < image->tile_size; i++ ) {
        if ( DEBUG >= 1 )
    		printf("%i/%i: %i\n",i,image->tile_size-1,((char *)SvPVX(buffer))[i]);
        if ( av_store( array, i, newSViv( ((char *)SvPVX(buffer))[i] ) ) == NULL ) {
            croak("Couldn't store buffer value in array.");
    	}
    }
    // FREE THE BUFFER!
	SvREFCNT_dec(buffer);

    return newRV_noinc((SV*)array);
}

SV* get_tiles(SV* obj, int ul_tile, int br_tile) {
    // 3D array of tile data
    Image* image = (Image*)SvIV(SvRV(obj));
    int tile_rows = (br_tile - ul_tile) / image->tile_step + 1;
    int tile_cols = (br_tile - ul_tile) % image->tile_step + 1;
    int r,c,tr;
    AV* tile_buffer;
    AV* tile_row;
    tile_buffer = newAV();      	// Stores tile row AV's (3D)
    av_extend( tile_buffer, tile_rows - 1 );
    // Fill the tile buffer
    for ( r = 0; r < tile_rows; r++ ) {
        tile_row = newAV();         // Stores tiles in a tile row
        av_extend( tile_row, tile_cols - 1 );
        // The starting tile # of the row (get from ul_tile)
        tr = ul_tile + r * image->tile_step;
        for ( c = 0; c < tile_cols; c++ ) {
            if ( av_store( tile_row, c, get_tile(obj,(tr + c)) ) == NULL )
                croak("Couldn't store buffer arrayref in tile_row array.");
        }
        if ( av_store( tile_buffer, r, newRV_noinc((SV*)tile_row) ) == NULL )
            croak("Couldn't store tile_row arrayref in tile_buffer.");
    }
	return newRV_noinc((SV*)tile_buffer);
}

//--------------------------------------------------------------------------------------------------
// ITERATION

void print_refcnt(SV* ref) {
    if ( DEBUG >= 1 )
        printf("Reference count of [ref,array]: [%i,%i]\n",SvREFCNT(ref),SvREFCNT((SV*)SvRV(ref)));
}

SV* _get_x_values(SV* shape, double y) {
    SV* x_values;
    int count;
    int i;
    dSP;
    PUSHMARK(SP);
    XPUSHs(shape);
    XPUSHs(sv_2mortal(newSVnv(y)));
    PUTBACK;
    count = call_method( "Image::GeoTIFF::Tiled::Shape::get_x", G_SCALAR );
    SPAGAIN;
    if ( count != 1 )
        croak("Image::GeoTIFF::Tiled::Shape::get_x didn't return a sole value.");
    x_values = POPs;
    PUTBACK;

    if ( SvTYPE(SvRV(x_values)) != SVt_PVAV )
        croak("Image::GeoTIFF::Tiled::Shape::get_x didn't return a reference to an array.");
    if ( DEBUG >= 1 ) {
        print_refcnt(x_values);
        printf("x_values at latitude %.1f: ",y);
        for ( i = 0; i < (int)(av_len( (AV*)SvRV(x_values) )) + 1; i++ )
            printf("%.2f ", SvNV((SV*)*av_fetch( (AV*)SvRV(x_values), i, 0 )));
        printf("\n");
    }
    return x_values;
}

static int _get_state(int old_state, double px, double* next_x, double* x_values, int xv_length, int* x_idx) {
    // First see if there's any x values left to check
    if ( *x_idx >= xv_length ) {
        if ( DEBUG >= 1 )
            printf("x_idx > length(x_values), returning %i\n",old_state);
        return old_state;
    }
    
    if ( DEBUG >= 1 ) {
        printf("State: %i; px: %.2f; x-value[%i]: %.2f\n",old_state,px,*x_idx,*next_x);
    }
    
    // Check if the middle of the pixel is to the right of the value
    if ( px >= *next_x ) {
        if ( DEBUG >= 1 )
            printf("px >= next_x\n");
        // Increment x index and fetch next x
        *x_idx = *x_idx + 1;
        if ( *x_idx <= xv_length ) {
            *next_x = x_values[*x_idx];
        }
        // Change state and recurse
        if ( old_state == 0 )
            return _get_state(1,px,next_x,x_values,xv_length,x_idx);
        else
            return _get_state(0,px,next_x,x_values,xv_length,x_idx);
    }
    else {
        if ( DEBUG >= 1 )
            printf("px < next_x, returning %i\n",old_state);
        return old_state;
    }
}


SV* extract_2D_array(SV* obj, SV* svx_min, SV* svy_min, SV* svx_max, SV* svy_max, SV* shape) {
//SV* extract_2D_array(SV* obj, SV* svx_min, SV* tile_buffer, SV* shape) { 
    Image* image = (Image*)SvIV(SvRV(obj));
    // Iteration local vars
    int ul_tile, br_tile;
    int rows,cols,tile_rows,tile_cols;
    int idx_row,idx_beg,idx_end;
    int i,r,c,tx,ty;
    // State-machine vars
    int shape_OK;                       // Flag to constrain pixels to shape
    int state;                          // Current state - either OUTSIDE(0) or INSIDE(1)
    SV* x_values;                       // Returned from Image::GeoTIFF::Tiled::Shape::get_x
    double* dx_values;                  // Copy of x_values
    int xv_length;                      // Array length of x_values
    double px,py;                       // Current pixel coordinate
    double next_x;                      // "Next" x_value in current latitude
    int x_idx;                          // Current index into x_values array

    // Data structures
    SV* tile_buffer;                    // Temp: Entire tile data		3D
    AV* tile_row;                       // Temp: A row of tile data		2D
    AV* data;                           // Temp: A tile of data			1D
    AV* buffer_row;                     // One row of buffered data
    AV* buffer = newAV();               // 2D array of buffer_row's (return data)
    
    if ( DEBUG >= 1 ) {
        printf( "Extracting 2D array of boundary (%.2f,%.2f,%.2f,%.2f)\n",
        	SvNV(svx_min),SvNV(svy_min),SvNV(svx_max),SvNV(svy_max) );
    }
       
    ul_tile = 
        get_tile_pix( obj, (double)SvNV(svx_min), (double)SvNV(svy_min) );
                                                            // x_min, y_min
    br_tile = 
        get_tile_pix( obj, (double)SvNV(svx_max), (double)SvNV(svy_max) );
                                                            // x_max, y_max
    tile_buffer = get_tiles(obj,ul_tile,br_tile);           // 3D tile data
    
    rows = (int)SvIV(svy_max) - (int)SvIV(svy_min) + 1;     // Pixel rows ( inclusive; y_max - y_min + 1 )
    av_extend( buffer, rows - 1 );
    cols = (int)SvIV(svx_max) - (int)SvIV(svx_min) + 1;     // Pixel cols ( inclusive; x_max - x_min + 1 )
    tile_rows = (br_tile - ul_tile) / image->tile_step + 1;
    tile_cols = (br_tile - ul_tile) % image->tile_step + 1;
    idx_row = 
        ( (int)SvIV(svy_min) - ((int)SvIV(svy_min) / image->tile_length) * image->tile_length ) * image->tile_length;
                                                            // first pixel index in the UL tile row (tile[y_min][0])
    idx_beg = idx_row + ((int)SvIV(svx_min) % image->tile_width);
                                                            // UL boundary pixel index (tile[y_min][x_min])
    idx_end = idx_row + ((int)SvIV(svx_max) % image->tile_width);
                                                            // UR boundary pixel index (tile[y_min][x_max])
    // Test if we're confining to a shape
    if ( sv_isobject(shape) && sv_isa(shape,"Image::GeoTIFF::Tiled::Shape") ) {
        // We ARE using a state machine
        shape_OK = 1;
        x_idx = 0;
        // Set the first pixel coordinate
        px = SvNV(svx_min) + 0.5;
        py = SvNV(svy_min) + 0.5;
        if ( DEBUG >= 1 )
            printf("Starting pixel coordinate: (%.1f,%.1f)\n",px,py);
    }
    else {
        // We're NOT using a state machine
        shape_OK = 0;
    }
    
    if ( DEBUG >= 1 ) {
        setvbuf(stdout, NULL, _IONBF, 0);   // autoflush
        printf("Starting pixel index: %d\nEnding pixel index: %d\nFirst pixel in row: %d\nRow step: %d\nTotal rows|cols: %i|%i\n",
            idx_beg,idx_end,idx_row,image->tile_length,rows,cols);
    }

//     Note:
//     cols = (idx_row + 64 - idx_beg)            First tile
//                + (64 * _min((tile_cols - 2),0) Middle tiles
//                + (idx_end - idx_row)           Last tile
//     ex. 
//        Buffer (rows,cols): (50,51)
//        Starting pixel index: 1647
//        Ending pixel index: 1634
//        First pixel in row: 1600
//        51 = 1600 + 64 - 1647 + 64 * 0 + 1634 - 1600
    
    tx = 0;
    for ( r = 0; r < rows; r++ ) {
        // WITHIN PIXEL ROW
        
//         - ex. Tiles are flattened 64 x 64 pixel grids
//            - index row given by idx / 64
//            - index col given by idx % 64
        c = 0;          // current buffer column index
        ty = 0;         // current tile_buffer column index (2nd dimension)
        
        buffer_row = newAV();               // Stores all pixel data on row (pixel latitude)
        av_extend( buffer_row, cols - 1 );
        
        if ( shape_OK ) {
            state = 0;
            x_idx = 0;
            x_values = _get_x_values(shape,py);    // Change state whenever we cross any of these guys
            xv_length = av_len( (AV*)SvRV(x_values) ) + 1;
            // Allocate and copy x_values into double* dx_values
            Newx(dx_values,xv_length,double);
            for ( i = 0; i < xv_length; i++ ) {
                dx_values[i] = (double)SvNV( (SV*)*av_fetch((AV*)SvRV(x_values), i, 0) ); 
            }
            if ( av_len( (AV*)SvRV(x_values) ) != -1 ) {
                next_x = (double)SvNV( (SV*)*av_fetch((AV*)SvRV(x_values), 0, 0) );
            }
        }
        
        // First tile: start somewhere in the idx_row
        for ( i = idx_beg; ( ty < tile_cols - 1 || i <= idx_end ) && i < idx_row + image->tile_width; i++ ) {
//          Fetch tile_buffer[tx][ty][i]:
            tile_row = (AV*)SvRV( *av_fetch( (AV*)SvRV(tile_buffer), tx, 0 ) );
            data = (AV*)SvRV( *av_fetch( tile_row, ty, 0 ) );
            // Update state machine
            if ( shape_OK ) {
                state = _get_state( state, px, &next_x, dx_values, xv_length, &x_idx );
                px++;
            }
            if ( shape_OK && state == 0 ) {
                av_store( buffer_row, c++, newSViv(-1) );
            }
            else {
                av_store( buffer_row, c++, newSVsv((SV*)*av_fetch(data,i,0)) );
            }
        }
        
        // Middle tiles: get entire idx_row (skipped if tile_cols < 3)
        for ( ty = 1; ty < tile_cols - 1; ty++ ) {
            for ( i = idx_row; i < idx_row + image->tile_width; i++ ) {
//              Fetch tile_buffer[tx][ty][i]:
                tile_row = (AV*)SvRV( *av_fetch( (AV*)SvRV(tile_buffer), tx, 0 ) );
                data = (AV*)SvRV( *av_fetch(tile_row,ty,0) );
                // Update state machine
                if ( shape_OK ) {
                    state = _get_state( state, px, &next_x, dx_values, xv_length, &x_idx );
                    px++;
                }
                if ( shape_OK && state == 0 ) {
                    av_store( buffer_row, c++, newSViv(-1) );
                }
                else {
                    av_store( buffer_row, c++, newSVsv((SV*)*av_fetch(data,i,0)) );
                }
            }
        }
        
        // Last tile: end in middle somewhere (skipped if tile_cols = 1)
        if ( tile_cols > 1 ) {
            for ( i = idx_row; i <= idx_end; i++ ) {
//              Fetch tile_buffer[tx][tile_cols-1][i]:
                tile_row = (AV*)SvRV( *av_fetch( (AV*)SvRV(tile_buffer), tx, 0 ) );
                data = (AV*)SvRV( *av_fetch(tile_row, tile_cols-1, 0) );
                // Update state machine
                if ( shape_OK ) {
                    state = _get_state( state, px, &next_x, dx_values, xv_length, &x_idx );
                    px++;
                }
                if ( shape_OK && state == 0 ) {
                    av_store( buffer_row, c++, newSViv(-1) );
                }
                else {
                    av_store( buffer_row, c++, newSVsv((SV*)*av_fetch(data,i,0)) );
                }
            }
        }
        
        // Note: at this point c = cols, hopefully
        if ( c != cols ) {
            printf("c: %d\tcols: %d\n",c,cols);
            croak("Buffer read error: c != cols (fix this!)");
        }
        
        // Store the buffer_row
		if ( av_store( buffer, r, newRV_noinc((SV*)buffer_row) ) == NULL )
            croak("Couldn't store buffer_row arrayref in 2D buffer array.");
        
        // Next row indexes
        if ( idx_row == image->tile_size - image->tile_width ) {
            // We've reached the last index row in the current tile buffer row
            tx++;    // increment tile_buffer row
            idx_beg = idx_beg % image->tile_width;
            idx_row = 0;
            idx_end = idx_end % image->tile_width;
        }
        else {
            // We're still in the middle of a tile
            idx_beg += image->tile_length;
            idx_row += image->tile_length;
            idx_end += image->tile_length;
        }
        if ( shape_OK ) {
            // Reset pixel column
            px = (double)SvNV(svx_min) + 0.5;
            // Increment the pixel row
            py++;
            // Free temps
            Safefree(dx_values);
        }
    }
    // FREE tile_buffer (3D Tile Data)
    SvREFCNT_dec(tile_buffer);

	return newRV_noinc((SV*)buffer);
}

//--------------------------------------------------------------------------------------------------
// GETTERS

char* file(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->file;
}
int length(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->length;
}
int width(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->width;
}
int tile_length(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->tile_length;
}
int tile_width(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->tile_width;
}
int tile_size(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->tile_size;
}
int tile_step(SV* obj) {
    return ((Image*)SvIV(SvRV(obj)))->tile_step;
}

//--------------------------------------------------------------------------------------------------
// CONSTRUCTOR

SV* new( char* class, const char* file ) {
    Image* image;
    SV*      obj_ref = newSV(0);
    SV*      obj = newSVrv(obj_ref, class);
    
//    New(42, image, 1, Image);
    Newx(image, 1, Image);
    
    image->file = savepv(file);
    
    // Open the TIFF image
    if ( (image->xtif = XTIFFOpen(file, "r")) == NULL )
        croak("Could not open incoming image");
   
    // Open the geotiff information handle on image
    if ( (image->gtif = GTIFNew(image->xtif)) == NULL )
        croak("Could not read geotiff data on image.");
    
    _verify_image(image);
    _read_meta(image);
    
    sv_setiv(obj, (IV)image);
    SvREADONLY_on(obj);
    
    return obj_ref;
}

void DESTROY(SV* obj) {
    Image* image = (Image*)SvIV(SvRV(obj));
    Safefree(image->file);
    GTIFFree(image->gtif);
    XTIFFClose(image->xtif);
    Safefree(image);
}

