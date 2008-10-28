#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 19;
use Config::Ini::Expanded;

my $ini_data = do{ local $/; <DATA> };

Interpolation: {
    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );
    is( $ini->get( section2 => 'name' ), 'cow',
        'get() (INI interpolated)' );
    is( $ini->get( section2 => 'name2' ), "cow\n",
        'get() (INI interpolated)' );
    my $uninterpolated = $ini->get( section1 => 'name2' );
    is( $uninterpolated, '{INI:section4:name}', '(uninterpolated)' );
    is( $ini->interpolate( $uninterpolated ), '{INI:section1:name}',
        'interpolate()' );
    is( $ini->expand( $uninterpolated ), 'cow', 'expand()' );
    is( $ini->get_interpolated( section1 => 'name2' ), '{INI:section1:name}',
        'get_interpolated()' );
    is( $ini->get( section6 => 'cow' ), 'cow',
        'interpolated name' );
    is( $ini->get( section6 => 'horse' ), 'horse',
        'interpolated name (heredoc)' );
}

Expand_Methods: {
    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );
    is( $ini->get_expanded( section3 => 'name' ), 'cow',
        'get_expanded()' );
    my $unexpanded = $ini->get( section3 => 'name' );
    is( $unexpanded, '{INI:section1:name}', '(unexpanded)' );
    is( $ini->expand( $unexpanded ), 'cow', 'expand()' );
}

Postponed_Interpolation: {
    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );
    my $postponed = $ini->get( section1 => 'name3' );
    is( $postponed, '{INI:section4:name2}',
        'get() (postponed interpolation)' );
    $postponed = $ini->interpolate( $postponed );
    is( $postponed, '{INI:section1:name}',
        'get() (postponed interpolation again)' );
    is( $ini->get_interpolated( section4 => 'name2' ),
        '{INI:section1:name}', 'get_interpolated() (postponed)' );
    $postponed = $ini->get( section5 => 'name' );
    is( $postponed, '!{INI:section1:name}',
        'get() (postponed interpolation)' );
    is( $ini->interpolate( $postponed ), '{INI:section1:name}',
        'interpolate() (postponed again)' );
}

Postponed_Expansion: {
    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );
    my $postponed = $ini->get( section1 => 'name3' );
    is( $ini->expand( $postponed ), '{INI:section1:name}',
        'expand() (postponed)' );
    is( $ini->get_expanded( section4 => 'name2' ),
        '{INI:section1:name}', 'get_expanded() (postponed)' );
    $postponed = $ini->get( section5 => 'name' );
    is( $ini->expand( $postponed ), '{INI:section1:name}',
        'expand() (postponed again)' );
}

__DATA__
[section1]
name = cow
name2 = {INI:section4:name}
name3 = "!{INI:section4:name2}"

[section2]
name = "{INI:section1:name}"
name2 = <<""
{INI:section1:name}
<<

[section3]
name = {INI:section1:name}

[section4]
name = {INI:section1:name}
name2 = <<:chomp
!{INI:section1:name}
<<

[section5]
name  = "!!{INI:section1:name}"

[section6]
name = horse
"{INI:section1:name}" = "{INI:section1:name}"
"{INI:section6:name}" = <<":chomp"
{INI:section6:name}
<<

