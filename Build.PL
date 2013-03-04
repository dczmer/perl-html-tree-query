use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'HTML::Tree::Query',
    license             => 'artistic_2',
    dist_author         => q{Dave Czmer <dczmer@gmail.com>},
    dist_version_from   => 'lib/HTML/Tree/Query.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Data::Dumper' => 0,
        'Carp' => 0,
        'Test::More' => 0,
        'Test::Deep' => 0,
        'Test::Exception' => 0,
        'Test::NoWarnings' => 0,
        'Test::MockObject::Extends' => 0,
        'Test::Class' => 0,
        'Test::MockObject' => 0,
        'Test::Pod::Coverage' => 0,
    },
    requires => {
        'ExtUtils::CBuilder' => 0,
        'HTML::Tree' => '5.03',
        'CSS::Selector::Parser' => '0.003',
    },
    add_to_cleanup     => [ 'HTML-Tree-Query-*' ],
    create_makefile_pl => 'traditional',
    recursive_test_files => 1,
);

$builder->create_build_script();
