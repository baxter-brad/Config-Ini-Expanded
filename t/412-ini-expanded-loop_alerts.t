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
my @tests_to_succeed;
my @tests_to_fail;

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

loop_deep = {LOOP:loop_deep1}{LVAR:too_deep1}{END_LOOP:loop_deep1}

# test unless_loop with loop_limit = 2 or size_limit = 20

unless_loop1 = {UNLESS_LOOP:dummy}{INI:to_test:unless_loop2}{END_UNLESS_LOOP:dummy}

unless_loop2 = {UNLESS_LOOP:dummy}{INI:to_test:unless_loop3}{END_UNLESS_LOOP:dummy}

unless_loop3 = "Hello, World."

unless_loop = {UNLESS_LOOP:dummy}{INI:to_test:unless_loop1}{END_UNLESS_LOOP:dummy}

[tests_to_succeed]

tmpl = {INI:to_test:loop_deep}
 out = Hello, World.
 cmt = Okay deep loop;

tmpl = {INI:to_test:unless_loop}
 out = Hello, World.
 cmt = Okay unless loop;

[tests_to_fail]

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
    @tests_to_succeed = $ini->get( tests_to_succeed => 'tmpl' );
    @tests_to_fail    = $ini->get( tests_to_fail    => 'tmpl' );
    $num_tests = @tests_to_succeed + @tests_to_fail;
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

# these get_expanded() calls are expected to succeed ...
for my $occ ( 0 .. $#tests_to_succeed ) {

    my $section = 'tests_to_succeed';

    my $output = $ini->get_expanded( $section => 'tmpl', $occ );
    my $wanted  = $ini->get( $section => 'out', $occ );
    my $comment = $ini->get( $section => 'cmt', $occ );

    is( $output, $wanted, $comment );
}

# these get_expanded() calls are expected to die ...
for my $occ ( 0 .. $#tests_to_fail ) {

    my $section = 'tests_to_fail';

    my $llim = $ini->get( $section => 'llim', $occ );
    my $slim = $ini->get( $section => 'slim', $occ );
    $ini->loop_limit( $llim );
    $ini->size_limit( $slim );

    eval { $ini->get_expanded( $section => 'tmpl', $occ ) };
    my $output  = $@;
    my $wanted  = $ini->get( $section => 'out', $occ );
    my $comment = $ini->get( $section => 'cmt', $occ );

    like( $output, qr/$wanted/, $comment );
}

__END__
