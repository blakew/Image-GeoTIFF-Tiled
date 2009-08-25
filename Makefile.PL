use 5.9.3;
use Inline::MakeMaker;
WriteMakefile(
    NAME              => 'Geo::TiledTIFF',
    VERSION_FROM      => 'lib/Geo/TiledTIFF.pm', # finds $VERSION
    PREREQ_PM         => { Module::Load => 0.16 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Geo/TiledTIFF.pm', # retrieve abstract from module
       AUTHOR         => 'Blake Willmarth <bwillmarth@gmail.com>') : ()),
);
