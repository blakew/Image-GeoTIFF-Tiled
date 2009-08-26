#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
#use Data::Dumper;
use Test::More qw/ no_plan /;
use Geo::TiledTIFF::ShapePart;

#BEGIN {
#    use_ok( q{Geo::TiledTIFF::ShapePart} );
#}

my @fail = (
    1,
    [ 1, 1 ],
    { },
    [ ],
    [ [], [] ],
    [ [ 1, 1 ], [ undef, 2 ] ],
#    [ [ -1, 1 ], [2, 2] ]
);
for my $f (@fail) {
    eval { my $sp = Geo::TiledTIFF::ShapePart->new( $f ); };
    ok( $@, $@ );
}

my @tests = (
    { 
        use =>      [ [ 0, 0 ], [ 0, 0 ] ],
        expect =>   [ ],
        get =>      [
            [ -1, undef ],
            [ 0, undef ],
            [ 1, undef ]
        ],
    },
    { 
        use =>      [ [ 0, 0 ], [ 0, 1 ] ],
        expect =>   [ [ 0, 0.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [ 0, 0.5 ] ],
            [ 1, undef ]
        ],
    },
    { 
        use =>      [ [ 0, 0 ], [ 1, 0 ] ],
        expect =>   [ ],
        get =>      [
            [ -1, undef ],
            [ 0, undef ],
            [ 1, undef ]
        ],
    },
    { 
        use =>      [ [ 0, 0 ], [ 1, 1 ] ],
        expect =>   [ [ 0.5, 0.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [0.5, 0.5] ],
            [ 1, undef ]
        ],
    },
    {
        use =>      [ [ 0, 0 ], [ 2, 2 ] ],
        expect =>   [ [ 0.5, 0.5 ], [ 1.5, 1.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [0.5, 0.5] ],
            [ 0.01, [0.5, 0.5] ],
            [ 0.5, [0.5, 0.5] ],
            [ 0.6, [0.5, 0.5] ],
            [ 0.99, [0.5, 0.5] ],
            [ 1, [1.5, 1.5] ],
            [ 2, undef ]
        ],
    },
    {
        use =>      [ [ 0.4, 0.4 ], [ 2.1, 2.1 ] ],
        expect =>   [ [ 0.5, 0.5 ], [ 1.5, 1.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [0.5, 0.5] ],
            [ 1, [1.5, 1.5] ],
            [ 2, undef ]
        ],
    },
    {
        use =>      [ [ 0.4, 0.4 ], [ 2.6, 2.6 ] ],
        expect =>   [ [ 0.5, 0.5 ], [ 1.5, 1.5 ], [ 2.5, 2.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [0.5, 0.5] ],
            [ 1, [1.5, 1.5] ],
            [ 2, [2.5, 2.5] ],
            [ 3, undef ]
        ],
    },
    {
        use =>      [ [ 0.6, 0.6 ], [ 2.6, 2.6 ] ],
        expect =>   [ [ 1.5, 1.5 ], [ 2.5, 2.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, undef ],
            [ 1, [1.5, 1.5] ],
            [ 2, [2.5, 2.5] ],
        ],
    },
    {
        use =>      [ [ 0.5, 0.5 ], [ 2.5, 2.5 ] ],
        expect =>   [ [ 0.5, 0.5 ], [ 1.5, 1.5 ], [ 2.5, 2.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, [0.5, 0.5] ],
        ],
    },
    {
        use =>      [ [ 1, 3 ], [ 3, 1 ] ],
        expect =>   [ [ 2.5, 1.5 ], [ 1.5, 2.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, undef ],
            [ 1, [2.5, 1.5] ],
            [ 2, [1.5, 2.5] ],
            [ 3, undef ]
        ]
    },
    {
        use =>      [ [ 3, 1 ], [ 1, 3 ] ],
        expect =>   [ [ 2.5, 1.5 ], [ 1.5, 2.5 ] ],
        get =>      [
            [ -1, undef ],
            [ 0, undef ],
            [ 1, [2.5, 1.5] ],
            [ 2, [1.5, 2.5] ],
            [ 3, undef ]
        ]
    }
);

for my $t ( @tests ) {
    my $sp = Geo::TiledTIFF::ShapePart->new( @{$t->{use}} );
#    print Dumper $sp unless
#        is_deeply( $sp->{_points}, $t->{expect}, $sp->str );
    # Test get_point()
    for ( @{$t->{get}} ) {
        my ($y,$p) = @{$_};
        if ( !defined $p ) {
            is( $sp->get_point($y), undef, "Get $y - undef" );
        }
        else {
            is_deeply( $sp->get_point($y), $p, "Get $y: (".$p->[0].",".$p->[1].")" );
        }
    }
}


