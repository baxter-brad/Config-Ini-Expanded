#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 2;
use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;
use Config::Ini::Expanded;

my $ini_data = do{ local $/; <DATA> };

# tests a bug fix where a call to get() was
# autovivifying nodes when checking for a value

Autoviv_get: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Expanded->new( string => $data );
    my $dump1 = Dumper $ini1;

    my $try = $ini1->get(              bad => 'bad' );  # doesn't exist
    $try    = $ini1->get_interpolated( bad => 'bad' );
    $try    = $ini1->get_expanded(     bad => 'bad' );
    $try    = $ini1->get_var(                 'bad' );
    $try    = $ini1->get_loop(                'bad' );
    $try    = $ini1->get_comments(     bad => 'bad' );
    $try    = $ini1->get_comment(      bad => 'bad' );
    $try    = $ini1->get_section_comments(    'bad' );
    $try    = $ini1->get_section_comment(     'bad' );

    my $dump2 = Dumper $ini1;  # bug was: 'bad' got autovived into $ini1

    is( $dump2, $dump1, 'autoviv in get()' );

}

Autoviv_get_names: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Expanded->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_names( 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_names()' );

}

__DATA__
[good]
good = good
