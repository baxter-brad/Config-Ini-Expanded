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

# define the array of hashes in ini data (just because)
forest = <<:json
[
  { tree:      "trident maple",
    order:     "sapindales",
    family:    "aceraceae",
    genus:     "acer",
    species:   "acer buergerianum"
  },
  { tree:      "southern live oak",
    order:     "fagales",
    family:    "fagaceae",
    genus:     "quercus",
    species:   "quercus virginiana"
  },
  { tree:      "longleaf pine",
    order:     "pinales",
    family:    "pinaceae",
    genus:     "pinus",
    species:   "pinus palustris"
  },
  { tree:      "maidenhair tree",
    order:     "ginkgoales",
    family:    "ginkgoaceae",
    genus:     "ginkgo",
    species:   "ginkgo biloba"
  },
  { tree:      "american beech",
    order:     "fagales",
    family:    "fagaceae",
    genus:     "fagus",
    species:   "fagus grandifolia"
  },
  { tree:      "american chestnut",
    order:     "fagales",
    family:    "fagaceae",
    genus:     "castanea",
    species:   "castanea dentata"
  }
]
<<

[tests]

#---------------------------------------------------------------------
# typical report loop

tmpl = <<:chomp
{LOOP:forest}Tree: {LVAR:tree}, Species: {LVAR:species}, Genus: {LVAR:genus}, Family: {LVAR:family}, Order: {LVAR:order}
{END_LOOP:forest}
<<
out = <<
Tree: trident maple, Species: acer buergerianum, Genus: acer, Family: aceraceae, Order: sapindales
Tree: southern live oak, Species: quercus virginiana, Genus: quercus, Family: fagaceae, Order: fagales
Tree: longleaf pine, Species: pinus palustris, Genus: pinus, Family: pinaceae, Order: pinales
Tree: maidenhair tree, Species: ginkgo biloba, Genus: ginkgo, Family: ginkgoaceae, Order: ginkgoales
Tree: american beech, Species: fagus grandifolia, Genus: fagus, Family: fagaceae, Order: fagales
Tree: american chestnut, Species: castanea dentata, Genus: castanea, Family: fagaceae, Order: fagales
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

tmpl = Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:tree}, {ELSE}and {LVAR:tree}{END_UNLESS_LC:last}{END_LOOP:forest}.
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, and american chestnut.
 cmt = UNLESS_LC:last with ELSE

cmt  = UNLESS_LC:last with ELSE, IF_LC:break(3) with ELSE
tmpl = <<:chomp
Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:tree},{IF_LC:break(3)}
{ELSE} {END_IF_LC:break(3)}{ELSE}and {LVAR:tree}{END_UNLESS_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

# the following shows explicitly which IF/UNLESS belongs to which ELSE ...

cmt  = UNLESS_LC:last with ELSE (explicit), IF_LC:break(3) with ELSE (explicit)
tmpl = <<:chomp
Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:tree},{IF_LC:break(3)}
{ELSE_IF_LC:break(3)} {END_IF_LC:break(3)}{ELSE_UNLESS_LC:last}and {LVAR:tree}{END_UNLESS_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

#---------------------------------------------------------------------
# IF_LVAR/UNLESS_LVAR

cmt  = IF_LVAR, UNLESS_LVAR, one way
tmpl = {LOOP:forest}{IF_LVAR:tree}{UNLESS_LVAR:lvar_null} {LVAR:tree}{END_UNLESS_LVAR:lvar_null}{END_IF_LVAR:tree}{END_LOOP:forest}
out  = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = UNLESS_LVAR, IF_LVAR, the other way
tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}{IF_LVAR:tree} {LVAR:tree}{END_IF_LVAR:tree}{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
out  = <<:chomp
 trident maple southern live oak longleaf pine maidenhair tree american beech american chestnut
<<

cmt  = IF_LVAR, UNLESS_LVAR with ELSE (unqualified)
tmpl = <<:join:chomp
{LOOP:forest}
{IF_LVAR:tree}
{UNLESS_LVAR:species} No species?{ELSE} {LVAR:species}
{END_UNLESS_LVAR:species}
{END_IF_LVAR:tree}
{END_LOOP:forest}
<<
out = <<:chomp
 acer buergerianum quercus virginiana pinus palustris ginkgo biloba fagus grandifolia castanea dentata
<<

cmt  = IF_LVAR, UNLESS_LVAR with ELSE (explicit)
tmpl = <<:join:chomp
{LOOP:forest}
{IF_LVAR:tree}
{UNLESS_LVAR:species} No species?{ELSE_UNLESS_LVAR:species} {LVAR:species}
{END_UNLESS_LVAR:species}
{END_IF_LVAR:tree}
{END_LOOP:forest}
<<
out = <<:chomp
 acer buergerianum quercus virginiana pinus palustris ginkgo biloba fagus grandifolia castanea dentata
<<

# this example is important to properly exercise the regex used
# for _disambiguate_else()

cmt  = UNLESS_LVAR, IF_LVAR, positive
tmpl = <<:join:chomp
{LOOP:forest}
{UNLESS_LVAR:species}
{IF_LVAR:tree} No species?{END_IF_LVAR:tree}
{ELSE}
{IF_LVAR:tree} {LVAR:species}{END_IF_LVAR:tree}
{END_UNLESS_LVAR:species}
{END_LOOP:forest}
<<
out = <<:chomp
 acer buergerianum quercus virginiana pinus palustris ginkgo biloba fagus grandifolia castanea dentata
<<

#---------------------------------------------------------------------
# IF_LOOP/UNLESS_LOOP

cmt  = IF_LOOP yes, LOOP
tmpl = <<:chomp
{IF_LOOP:forest}{LOOP:forest}Tree: {LVAR:tree}, Order: {LVAR:order}
{END_LOOP:forest}{END_IF_LOOP:forest}
<<
out = <<
Tree: trident maple, Order: sapindales
Tree: southern live oak, Order: fagales
Tree: longleaf pine, Order: pinales
Tree: maidenhair tree, Order: ginkgoales
Tree: american beech, Order: fagales
Tree: american chestnut, Order: fagales
<<

cmt  = IF_LOOP no, ELSE, LOOP
tmpl = <<:chomp
{IF_LOOP:loop_null}Ooops, there's a loop?{ELSE}{LOOP:forest}Tree: {LVAR:tree}, Order: {LVAR:order}
{END_LOOP:forest}{END_IF_LOOP:loop_null}
<<
out = <<
Tree: trident maple, Order: sapindales
Tree: southern live oak, Order: fagales
Tree: longleaf pine, Order: pinales
Tree: maidenhair tree, Order: ginkgoales
Tree: american beech, Order: fagales
Tree: american chestnut, Order: fagales
<<

cmt  = UNLESS_LOOP no, ELSE, LOOP
tmpl = <<:chomp
{UNLESS_LOOP:forest}Ooops, no loop?{ELSE}{LOOP:forest}Tree: {LVAR:tree}, Order: {LVAR:order}
{END_LOOP:forest}{END_UNLESS_LOOP:forest}
<<
out = <<
Tree: trident maple, Order: sapindales
Tree: southern live oak, Order: fagales
Tree: longleaf pine, Order: pinales
Tree: maidenhair tree, Order: ginkgoales
Tree: american beech, Order: fagales
Tree: american chestnut, Order: fagales
<<

cmt  = UNLESS_LOOP yes, LOOP
tmpl = <<:chomp
{UNLESS_LOOP:loop_null}{LOOP:forest}Tree: {LVAR:tree}, Order: {LVAR:order}
{END_LOOP:forest}{END_UNLESS_LOOP:loop_null}
<<
out = <<
Tree: trident maple, Order: sapindales
Tree: southern live oak, Order: fagales
Tree: longleaf pine, Order: pinales
Tree: maidenhair tree, Order: ginkgoales
Tree: american beech, Order: fagales
Tree: american chestnut, Order: fagales
<<

#---------------------------------------------------------------------
# IF_INI/UNLESS_INI

tmpl = <<:join:chomp
{IF_INI:loops:forest}
Families: {LOOP:forest}{LVAR:family}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_IF_INI:loops:forest}
<<
 out = Families: aceraceae, fagaceae, pinaceae, ginkgoaceae, fagaceae, fagaceae
 cmt = IF_INI, LOOP

tmpl = <<:join:chomp
{UNLESS_INI:loops:loop_null}
Families: {LOOP:forest}{LVAR:family}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_UNLESS_INI:loops:loop_null}
<<
 out = Families: aceraceae, fagaceae, pinaceae, ginkgoaceae, fagaceae, fagaceae
 cmt = UNLESS_INI, LOOP

#---------------------------------------------------------------------
# IF_VAR/UNLESS_VAR

tmpl = <<:join:chomp
{IF_VAR:hey}
Families: {LOOP:forest}{LVAR:family}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_IF_VAR:hey}
<<
 out = Families: aceraceae, fagaceae, pinaceae, ginkgoaceae, fagaceae, fagaceae
 cmt = IF_VAR, LOOP

tmpl = <<:join:chomp
{UNLESS_VAR:var_null}
Families: {LOOP:forest}{LVAR:family}
{UNLESS_LC:last}, {END_UNLESS_LC:last}
{END_LOOP:forest}
{END_UNLESS_VAR:var_null}
<<
 out = Families: aceraceae, fagaceae, pinaceae, ginkgoaceae, fagaceae, fagaceae
 cmt = UNLESS_VAR, LOOP

#---------------------------------------------------------------------
tmpl = last test
 out = last test
 cmt = last test

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

$ini->set_var(  hey    => "Hey."                          );
$ini->set_loop( forest => $ini->get( loops => 'forest' )  );

for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    my $output  = $ini->get_expanded( tests => 'tmpl', $occ );
    my $wanted  = $ini->get(          tests => 'out',  $occ );
    my $comment = $ini->get(          tests => 'cmt',  $occ );

    is( $output, $wanted, $comment );
}

__END__
