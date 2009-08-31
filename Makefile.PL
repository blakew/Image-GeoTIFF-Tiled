use 5.9.3;
use Inline::MakeMaker;
WriteMakefile(
    NAME              => 'Image::GeoTIFF::Tiled',
#    VERSION_FROM      => 'lib/Geo/TiledTIFF.pm', # finds $VERSION
    VERSION_FROM      => 'Tiled.pm', # finds $VERSION
    PREREQ_PM         => { Module::Load => 0.16,
                           List::MoreUtils => 0.16 },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Image/GeoTIFF/Tiled.pod', # retrieve abstract from module
       AUTHOR         => 'Blake Willmarth <bwillmarth@gmail.com>') : ()),
);
