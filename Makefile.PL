use 5.005;
eval 'use Inline::MakeMaker';
die "Inline required for building XS" if $@;
WriteMakefile(
    NAME              => 'Image::GeoTIFF::Tiled',
    VERSION_FROM      => 'Tiled.pm', # finds $VERSION
    PREREQ_PM         => { Module::Load => 0.16,
                           List::MoreUtils => 0.16 },
    ABSTRACT_FROM  => 'lib/Image/GeoTIFF/Tiled.pod', # retrieve abstract from module
    AUTHOR         => 'Blake Willmarth <bwillmarth@gmail.com>',
);
