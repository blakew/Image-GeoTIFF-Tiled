#!/usr/bin/perl

use Test::More tests => 1;

BEGIN {
	use_ok( 'Geo::TiledTIFF' );
    use_ok( 'Geo::TiledTIFF::Shape' );
    use_ok( 'Geo::TiledTIFF::ShapePart' );
    use_ok( 'Geo::TiledTIFF::Iterator' );
    use_ok( 'Module::Load' );
}

diag( "Testing Geo::TiledTIFF $Geo::TiledTIFF::VERSION, Perl $], $^X" );
