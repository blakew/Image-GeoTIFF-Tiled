use inc::Module::Install;

name     'Geo-TiledTIFF';
all_from 'lib/Geo/TiledTIFF.pm';
author   'Blake Willmarth <bwillmarth@gmail.com>';
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

