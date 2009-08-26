#!/usr/bin/perl

use Test::More tests => 6;

BEGIN {
    use_ok( 'Geo::TiledTIFF::ShapePart' );
    use_ok( 'Module::Load' );
    use_ok( 'Geo::TiledTIFF::Shape' );
    use_ok( 'Geo::TiledTIFF::Iterator' );
	use_ok( 'Geo::TiledTIFF::Image' );
	use_ok( 'Geo::TiledTIFF' );
}

diag( "Testing Geo::TiledTIFF $Geo::TiledTIFF::VERSION, Perl $], $^X" );
