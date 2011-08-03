#!/usr/local/bin/perl
use warnings;
use strict;

use Config::Ini::Expanded;

#---------------------------------------------------------------------

=for comment

These are intended to test the instance-level loop_limit and
size_limit settings.

=cut

#---------------------------------------------------------------------
# Setting up ...

my $ini;
my $num_tests;

BEGIN {
    my $ini_data = <<'_end_ini_';

#---------------------------------------------------------------------
# loop alerts

[to_test]

# test loop_deep with loop_limit = 2 (tests _expand_loop())

loop_deep1 = <<:json
[{ "too_deep1": "{LOOP:loop_deep2}{LVAR:too_deep2}{END_LOOP:loop_deep2}" }]
<<

loop_deep2 = <<:json
[{ "too_deep2": "{LOOP:loop_deep3}{LVAR:too_deep3}{END_LOOP:loop_deep3}" }]
<<

loop_deep3 = <<:json
[{ "too_deep3": "Hello, World." }]
<<

loop_deep = <<
{LOOP:loop_deep1}{LVAR:too_deep1}{END_LOOP:loop_deep1}
<<

# test unless_loop with loop_limit = 2 or size_limit = 20

unless_loop1 = <<
{UNLESS_LOOP:dummy}{INI:to_test:unless_loop2}{END_UNLESS_LOOP:dummy}
<<

unless_loop2 = <<
{UNLESS_LOOP:dummy}{INI:to_test:unless_loop3}{END_UNLESS_LOOP:dummy}
<<

unless_loop3 = "Hello, World."

unless_loop = <<
{UNLESS_LOOP:dummy}{INI:to_test:unless_loop1}{END_UNLESS_LOOP:dummy}
<<

[tests]

tmpl = {INI:to_test:loop_deep}
 out = Deep recursion alert
 cmt = LVAR/LOOP, deep recursion (small loop_limit)"
llim = '2'          # small enough to die
slim = '1000000'  # default

tmpl = {INI:to_test:unless_loop}
 out = Loop alert
 cmt = loop alert (small loop_limit)
llim = '2'          # small enough to die
slim = '1000000'  # default

tmpl = {INI:to_test:unless_loop}
 out = Loop alert
 cmt = loop alert (small size_limit)
llim = '10'  # default
slim = '50'  # small enough to die

_end_ini_

    $ini = Config::Ini::Expanded->new( string => $ini_data );

    # calculate how many tests for Test::More
    my @tests = $ini->get( tests => 'tmpl' );
    $num_tests = @tests;
}

# Yup, we need another BEGIN block ...
BEGIN {
    use Test::More tests => $num_tests;
}

#---------------------------------------------------------------------
# Testing ...

$ini->set_loop(
        loop_deep1     => $ini->get( to_test => 'loop_deep1'      ),
        loop_deep2     => $ini->get( to_test => 'loop_deep2'      ),
        loop_deep3     => $ini->get( to_test => 'loop_deep3'      ),
    );

# these get_expanded() calls are expected to die ...
for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;

    my $llim = $ini->get( tests => 'llim', $occ );
    my $slim = $ini->get( tests => 'slim', $occ );
    $ini->loop_limit( $llim );
    $ini->size_limit( $slim );

    eval { $ini->get_expanded( tests => 'tmpl', $occ ) };
    my $output  = $@;
    my $wanted  = $ini->get( tests => 'out', $occ );
    my $comment = $ini->get( tests => 'cmt', $occ );

    like( $output, qr/$wanted/, $comment );
}

__END__
