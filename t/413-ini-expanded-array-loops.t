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

[loops]

forest = <<:json
[
    "trident maple",
    "southern live oak",
    "longleaf pine",
    "maidenhair tree",
    "american beech",
    "american chestnut"
]
<<

[tests]

#---------------------------------------------------------------------
# typical report loop

tmpl = <<:chomp
{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<
cmt = Typical LOOP

#---------------------------------------------------------------------
# Loop Context Values, combinations

tmpl = {LOOP:forest}{IF_LC:last}[{LC:index}]{END_IF_LC:last}{END_LOOP:forest}
 out = [5]
 cmt = IF_LC:last, LC:index

tmpl = {LOOP:forest}{IF_LC:first}[{LC:counter}]{END_IF_LC:first}{IF_LC:last}[{LC:counter}]{END_IF_LC:last}{END_LOOP:forest}
 out = [1][6]
 cmt = IF_LC:first, IF_LC:last, LC:counter

tmpl = {LOOP:forest}{UNLESS_LC:first}[{LC:inner}]{END_UNLESS_LC:first}{END_LOOP:forest}
 out = [1][1][1][1][]
 cmt = UNLESS_LC:first, LC:inner

tmpl = {LOOP:forest}{UNLESS_LC:last}[{LC:inner}]{END_UNLESS_LC:last}{END_LOOP:forest}
 out = [][1][1][1][1]
 cmt = UNLESS_LC:last, LC:inner

tmpl = {LOOP:forest}{IF_LC:break(2)}[{LC:odd}]{END_IF_LC:break(2)}{END_LOOP:forest}
 out = [][][]
 cmt = IF_LC:break(2), LC:odd

tmpl = {LOOP:forest}{UNLESS_LC:break(2)}[{LC:odd}]{END_UNLESS_LC:break(2)}{END_LOOP:forest}
 out = [1][1][1]
 cmt = UNLESS_LC:break(2), LC:odd

tmpl = {LOOP:forest}{IF_LC:odd}[{LC:break(2)}]{END_IF_LC:odd}{END_LOOP:forest}
 out = [][][]
 cmt = IF_LC:odd, LC:break(2)

tmpl = {LOOP:forest}{UNLESS_LC:odd}[{LC:break(2)}]{END_UNLESS_LC:odd}{END_LOOP:forest}
 out = [1][1][1]
 cmt = UNLESS_LC:odd, LC:break(2)

tmpl = Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:forest}, {ELSE}and {LVAR:forest}{END_UNLESS_LC:last}{END_LOOP:forest}.
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, and american chestnut.
 cmt = UNLESS_LC:last with ELSE

tmpl = Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:forest}, {ELSE:last}and {LVAR:forest}{END_UNLESS_LC:last}{END_LOOP:forest}.
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, and american chestnut.
 cmt = UNLESS_LC:last with ELSE:last

cmt  = UNLESS_LC:last with ELSE, IF_LC:break(3) with ELSE
tmpl = <<:chomp
Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:forest},{IF_LC:break(3)}
{ELSE} {END_IF_LC:break(3)}{ELSE}and {LVAR:forest}{END_UNLESS_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

cmt  = UNLESS_LC:last with ELSE:last, IF_LC:break(3) with ELSE:break(3)
tmpl = <<:chomp
Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:forest},{IF_LC:break(3)}
{ELSE:break(3)} {END_IF_LC:break(3)}{ELSE:last}and {LVAR:forest}{END_UNLESS_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

# the following shows explicitly which IF/UNLESS belongs to which ELSE ...

cmt  = UNLESS_LC:last with ELSE (explicit), IF_LC:break(3) with ELSE (explicit)
tmpl = <<:chomp
Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:forest},{IF_LC:break(3)}
{ELSE_IF_LC:break(3)} {END_IF_LC:break(3)}{ELSE_UNLESS_LC:last}and {LVAR:forest}{END_UNLESS_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

#---------------------------------------------------------------------
# IF_LVAR/UNLESS_LVAR

cmt  = IF_LVAR, UNLESS_LVAR, one way
tmpl = {LOOP:forest}{IF_LVAR:forest}{UNLESS_LVAR:lvar_null} {LVAR:forest}{END_UNLESS_LVAR:lvar_null}{END_IF_LVAR:forest}{END_LOOP:forest}
out  = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = UNLESS_LVAR, IF_LVAR, the other way
tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}{IF_LVAR:forest} {LVAR:forest}{END_IF_LVAR:forest}{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
out  = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = IF_LVAR, UNLESS_LVAR with ELSE (unqualified)
tmpl = <<:join:chomp
{LOOP:forest}
{IF_LVAR:forest}
{UNLESS_LVAR:forest} No trees?{ELSE} {LVAR:forest}
{END_UNLESS_LVAR:forest}
{END_IF_LVAR:forest}
{END_LOOP:forest}
<<
out = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = IF_LVAR, UNLESS_LVAR with ELSE (named)
tmpl = <<:join:chomp
{LOOP:forest}
{IF_LVAR:forest}
{UNLESS_LVAR:forest} No trees?{ELSE:forest} {LVAR:forest}
{END_UNLESS_LVAR:forest}
{END_IF_LVAR:forest}
{END_LOOP:forest}
<<
out = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = IF_LVAR, UNLESS_LVAR with ELSE (explicit)
tmpl = <<:join:chomp
{LOOP:forest}
{IF_LVAR:forest}
{UNLESS_LVAR:forest} No species?{ELSE_UNLESS_LVAR:forest} {LVAR:forest}
{END_UNLESS_LVAR:forest}
{END_IF_LVAR:forest}
{END_LOOP:forest}
<<
out = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

#---------------------------------------------------------------------
# IF_LOOP/UNLESS_LOOP

cmt  = IF_LOOP yes, LOOP
tmpl = <<:chomp
{IF_LOOP:forest}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_IF_LOOP:forest}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

cmt  = IF_LOOP no, ELSE, LOOP
tmpl = <<:chomp
{IF_LOOP:loop_null}Ooops, there's a loop?{ELSE}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_IF_LOOP:loop_null}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

cmt  = IF_LOOP no, ELSE(named), LOOP
tmpl = <<:chomp
{IF_LOOP:loop_null}Ooops, there's a loop?{ELSE:loop_null}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_IF_LOOP:loop_null}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

cmt  = UNLESS_LOOP no, ELSE, LOOP
tmpl = <<:chomp
{UNLESS_LOOP:forest}Ooops, no loop?{ELSE}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_UNLESS_LOOP:forest}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

cmt  = UNLESS_LOOP no, ELSE(named), LOOP
tmpl = <<:chomp
{UNLESS_LOOP:forest}Ooops, no loop?{ELSE:forest}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_UNLESS_LOOP:forest}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

cmt  = UNLESS_LOOP yes, LOOP
tmpl = <<:chomp
{UNLESS_LOOP:loop_null}{LOOP:forest}Tree: {LVAR:forest}
{END_LOOP:forest}{END_UNLESS_LOOP:loop_null}
<<
out = <<
Tree: trident maple
Tree: southern live oak
Tree: longleaf pine
Tree: maidenhair tree
Tree: american beech
Tree: american chestnut
<<

#---------------------------------------------------------------------
# IF_INI/UNLESS_INI

tmpl = <<:join:chomp
{IF_INI:loops:forest}
Trees: {LOOP:forest}{LVAR:forest}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_IF_INI:loops:forest}
<<
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, american chestnut
 cmt = IF_INI, LOOP

tmpl = <<:join:chomp
{UNLESS_INI:loops:loop_null}
Trees: {LOOP:forest}{LVAR:forest}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_UNLESS_INI:loops:loop_null}
<<
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, american chestnut
 cmt = UNLESS_INI, LOOP

#---------------------------------------------------------------------
# IF_VAR/UNLESS_VAR

tmpl = <<:join:chomp
{IF_VAR:hey}
Trees: {LOOP:forest}{LVAR:forest}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_IF_VAR:hey}
<<
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, american chestnut
 cmt = IF_VAR, LOOP

tmpl = <<:join:chomp
{UNLESS_VAR:var_null}
Trees: {LOOP:forest}{LVAR:forest}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_UNLESS_VAR:var_null}
<<
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, american chestnut
 cmt = UNLESS_VAR, LOOP

#---------------------------------------------------------------------
_end_ini_

    $ini = Config::Ini::Expanded->new( string => $ini_data );

    # calculate how many tests for Test::More
    my @tests = $ini->get( tests => 'tmpl' );
    $num_tests = @tests;
}

# Yup, we need another BEGIN block ...
BEGIN {
    use Test::More tests => ( $num_tests * 2 );
}

#---------------------------------------------------------------------
# Testing ...

$ini->set_var(  hey    => "Hey."                          );
$ini->set_loop( forest => $ini->get( loops => 'forest' )  );

for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    my $output  = $ini->get_expanded( tests => 'tmpl', $occ );
    my $wanted  = $ini->get(          tests => 'out',  $occ );
    my $comment = $ini->get(          tests => 'cmt',  $occ );

    is( $output, $wanted, $comment );
}

for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    my $output  = $ini->get_interpolated( tests => 'tmpl', $occ );
    my $wanted  = $ini->get(              tests => 'out',  $occ );
    my $comment = $ini->get(              tests => 'cmt',  $occ );

    is( $output, $wanted, $comment );
}

__END__
