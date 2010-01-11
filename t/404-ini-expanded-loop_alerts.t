#!/usr/local/bin/perl
use warnings;
use strict;

use Config::Ini::Expanded;

#---------------------------------------------------------------------
# Setting up ...

my $ini;
my $num_tests;

BEGIN {
    my $ini_data = <<'_end_ini_';

#---------------------------------------------------------------------
# loop alerts

[to_test]

loop_deep = <<:json
[{ too_deep: "{LOOP:loop_deep}{LVAR:too_deep}{END_LOOP:loop_deep}" }]
<<

loop_var_lvar = <<:json
[{ var_lvar: "{VAR:var_lvar}" }]
<<

loop_ini_lvar = <<:json
[{ ini_lvar: "{INI:to_test:ini_lvar}" }]
<<

loop_lvar = <<:json
[{ lvar: "{LVAR:lvar}" }]
<<

var      = {VAR:var}
ini      = {INI:to_test:ini}
var_ini  = {VAR:var_ini}
var_lvar = {LOOP:loop_var_lvar}{LVAR:var_lvar}{END_LOOP:loop_var_lvar}
ini_lvar = {LOOP:loop_ini_lvar}{LVAR:ini_lvar}{END_LOOP:loop_ini_lvar}

[tests]

tmpl = {LOOP:loop_deep}{LVAR:too_deep}{END_LOOP:loop_deep}
 out = Deep recursion alert.*LVAR
 cmt = LVAR/LOOP, deep recursion ... {LVAR...} = "{LOOP...}{LVAR...}"

tmpl = {VAR:var}
 out = Loop alert.*VAR
 cmt = VAR, loop alert ... {VAR...} = "{VAR...}"

tmpl = {INI:to_test:ini}
 out = Loop alert.*INI
 cmt = INI, loop alert ... {INI...} = "{INI...}"

tmpl = {VAR:var_ini}
 out = Loop alert.*VAR
 cmt = VAR/INI, loop alert ... {VAR:xyz} = "{INI:abc:xyz}" and vice verse

tmpl = {INI:to_test:var_ini}
 out = Loop alert.*VAR
 cmt = INI/VAR, loop alert ... {INI:abc:xyz} = "{VAR:xyz}" and vice verse

tmpl = {VAR:var_lvar}
 out = Loop alert.*VAR
 cmt = VAR/LVAR, loop alert ... {VAR...} = "{LOOP...}{LVAR...}" and {LVAR...} = "{VAR...}"

tmpl = {INI:to_test:ini_lvar}
 out = Loop alert.*LOOP
 cmt = INI/LVAR, loop alert ... {INI...} = "{LOOP...}{LVAR...}" and {LVAR...} = "{INI...}"

tmpl = {LOOP:loop_lvar}{LVAR:lvar}{END_LOOP:loop_lvar}
 out = Loop alert.*LVAR
 cmt = LVAR/LOOP, loop alert ... {LVAR...} = "{LOOP...}{LVAR...}"

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

$ini->set_var(
        var      => $ini->get( to_test => 'var' ),
        var_ini  => "{INI:to_test:var_ini}",
        var_lvar => "{INI:to_test:var_lvar}",
    );

$ini->set_loop(
        loop_deep      => $ini->get( to_test => 'loop_deep'      ),
        loop_var_lvar  => $ini->get( to_test => 'loop_var_lvar'  ),
        loop_ini_lvar  => $ini->get( to_test => 'loop_ini_lvar'  ),
        loop_lvar      => $ini->get( to_test => 'loop_lvar'      ),
    );

# these get_expanded() calls are expected to die ...
for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    eval { $ini->get_expanded( tests => 'tmpl', $occ ) };
    my $output  = $@;
    my $wanted  = $ini->get( tests => 'out',  $occ );
    my $comment = $ini->get( tests => 'cmt',  $occ );

    like( $output, qr/$wanted/, $comment );
}

__END__
