#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'HTML::Tree::Query' ) || print "Bail out!\n";
}

diag( "Testing HTML::Tree::Query $HTML::Tree::Query::VERSION, Perl $], $^X" );
