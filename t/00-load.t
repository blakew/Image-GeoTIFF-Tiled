#!/usr/bin/perl

use Test::More tests => 5;

BEGIN {
    use_ok( 'Module::Load' );
    use_ok( 'Geo::TiledTIFF::ShapePart' );
    use_ok( 'Geo::TiledTIFF::Shape' );
    use_ok( 'Geo::TiledTIFF::Iterator' );
    use_ok( 'Geo::TiledTIFF' );
}

diag( "Testing Geo::TiledTIFF $Geo::TiledTIFF::VERSION, Perl $], $^X" );
