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
  { "tree":      "trident maple",
    "order":     "sapindales",
    "family":    "aceraceae",
    "genus":     "acer",
    "species":   "acer buergerianum"
  },
  { "tree":      "southern live oak",
    "order":     "fagales",
    "family":    "fagaceae",
    "genus":     "quercus",
    "species":   "quercus virginiana"
  },
  { "tree":      "longleaf pine",
    "order":     "pinales",
    "family":    "pinaceae",
    "genus":     "pinus",
    "species":   "pinus palustris"
  },
  { "tree":      "maidenhair tree",
    "order":     "ginkgoales",
    "family":    "ginkgoaceae",
    "genus":     "ginkgo",
    "species":   "ginkgo biloba"
  },
  { "tree":      "american beech",
    "order":     "fagales",
    "family":    "fagaceae",
    "genus":     "fagus",
    "species":   "fagus grandifolia"
  },
  { "tree":      "american chestnut",
    "order":     "fagales",
    "family":    "fagaceae",
    "genus":     "castanea",
    "species":   "castanea dentata"
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
# Loop Context Values

tmpl = {LOOP:forest}[{LC:index}]{END_LOOP:forest}
 out = [0][1][2][3][4][5]
 cmt = LC:index

tmpl = {LOOP:forest}[{LC:forest:index}]{END_LOOP:forest}
 out = [0][1][2][3][4][5]
 cmt = LC:...:index

tmpl = {LOOP:forest}[{LC:counter}]{END_LOOP:forest}
 out = [1][2][3][4][5][6]
 cmt = LC:counter

tmpl = {LOOP:forest}[{LC:forest:counter}]{END_LOOP:forest}
 out = [1][2][3][4][5][6]
 cmt = LC:...:counter

tmpl = {LOOP:forest}[{LC:first}]{END_LOOP:forest}
 out = [1][][][][][]
 cmt = LC:first

tmpl = {LOOP:forest}[{LC:forest:first}]{END_LOOP:forest}
 out = [1][][][][][]
 cmt = LC:...:first

tmpl = {LOOP:forest}[{LC:last}]{END_LOOP:forest}
 out = [][][][][][1]
 cmt = LC:last

tmpl = {LOOP:forest}[{LC:forest:last}]{END_LOOP:forest}
 out = [][][][][][1]
 cmt = LC:...:last

tmpl = {LOOP:forest}[{LC:inner}]{END_LOOP:forest}
 out = [][1][1][1][1][]
 cmt = LC:inner

tmpl = {LOOP:forest}[{LC:forest:inner}]{END_LOOP:forest}
 out = [][1][1][1][1][]
 cmt = LC:...:inner

tmpl = {LOOP:forest}[{LC:odd}]{END_LOOP:forest}
 out = [1][][1][][1][]
 cmt = LC:odd

tmpl = {LOOP:forest}[{LC:forest:odd}]{END_LOOP:forest}
 out = [1][][1][][1][]
 cmt = LC:...:odd

tmpl = {LOOP:forest}[{LC:break(0)}]{END_LOOP:forest}
 out = [][][][][][]
 cmt = LC:break(0)

tmpl = {LOOP:forest}[{LC:break(1)}]{END_LOOP:forest}
 out = [1][1][1][1][1][1]
 cmt = LC:break(1)

tmpl = {LOOP:forest}[{LC:break(2)}]{END_LOOP:forest}
 out = [][1][][1][][1]
 cmt = LC:break(2)

tmpl = {LOOP:forest}[{LC:break(3)}]{END_LOOP:forest}
 out = [][][1][][][1]
 cmt = LC:break(3)

tmpl = {LOOP:forest}[{LC:break(4)}]{END_LOOP:forest}
 out = [][][][1][][]
 cmt = LC:break(4)

tmpl = {LOOP:forest}[{LC:break(5)}]{END_LOOP:forest}
 out = [][][][][1][]
 cmt = LC:break(5)

tmpl = {LOOP:forest}[{LC:break(6)}]{END_LOOP:forest}
 out = [][][][][][1]
 cmt = LC:break(6)

tmpl = {LOOP:forest}[{LC:break(7)}]{END_LOOP:forest}
 out = [][][][][][]
 cmt = LC:break(7)

tmpl = {LOOP:forest}[{LC:forest:break(0)}]{END_LOOP:forest}
 out = [][][][][][]
 cmt = LC:...:break(0)

tmpl = {LOOP:forest}[{LC:forest:break(1)}]{END_LOOP:forest}
 out = [1][1][1][1][1][1]
 cmt = LC:...:break(1)

tmpl = {LOOP:forest}[{LC:forest:break(2)}]{END_LOOP:forest}
 out = [][1][][1][][1]
 cmt = LC:...:break(2)

tmpl = {LOOP:forest}[{LC:forest:break(3)}]{END_LOOP:forest}
 out = [][][1][][][1]
 cmt = LC:...:break(3)

tmpl = {LOOP:forest}[{LC:forest:break(4)}]{END_LOOP:forest}
 out = [][][][1][][]
 cmt = LC:...:break(4)

tmpl = {LOOP:forest}[{LC:forest:break(5)}]{END_LOOP:forest}
 out = [][][][][1][]
 cmt = LC:...:break(5)

tmpl = {LOOP:forest}[{LC:forest:break(6)}]{END_LOOP:forest}
 out = [][][][][][1]
 cmt = LC:...:break(6)

tmpl = {LOOP:forest}[{LC:forest:break(7)}]{END_LOOP:forest}
 out = [][][][][][]
 cmt = LC:...:break(7)

#---------------------------------------------------------------------
# IF_LC/UNLESS_LC (no ELSE)

cmt  = IF_LC:odd, UNLESS_LC:first
tmpl = <<:chomp
{LOOP:forest}{UNLESS_LC:first}{IF_LC:odd}
{END_IF_LC:odd}{END_UNLESS_LC:first}Tree: {LVAR:tree}, Species: {LVAR:species}
{END_LOOP:forest}
<<
out = <<
Tree: trident maple, Species: acer buergerianum
Tree: southern live oak, Species: quercus virginiana

Tree: longleaf pine, Species: pinus palustris
Tree: maidenhair tree, Species: ginkgo biloba

Tree: american beech, Species: fagus grandifolia
Tree: american chestnut, Species: castanea dentata
<<

cmt  = IF_LC:break(2), UNLESS_LC:last
tmpl = <<:chomp
{LOOP:forest}Tree: {LVAR:tree}, Species: {LVAR:species}
{UNLESS_LC:last}{IF_LC:break(2)}
{END_IF_LC:break(2)}{END_UNLESS_LC:last}{END_LOOP:forest}
<<
out = <<
Tree: trident maple, Species: acer buergerianum
Tree: southern live oak, Species: quercus virginiana

Tree: longleaf pine, Species: pinus palustris
Tree: maidenhair tree, Species: ginkgo biloba

Tree: american beech, Species: fagus grandifolia
Tree: american chestnut, Species: castanea dentata
<<

cmt  = IF_LC:...:odd, UNLESS_LC:...:first
tmpl = <<:chomp
{LOOP:forest}{UNLESS_LC:forest:first}{IF_LC:forest:odd}
{END_IF_LC:forest:odd}{END_UNLESS_LC:forest:first}Tree: {LVAR:tree}, Species: {LVAR:species}
{END_LOOP:forest}
<<
out = <<
Tree: trident maple, Species: acer buergerianum
Tree: southern live oak, Species: quercus virginiana

Tree: longleaf pine, Species: pinus palustris
Tree: maidenhair tree, Species: ginkgo biloba

Tree: american beech, Species: fagus grandifolia
Tree: american chestnut, Species: castanea dentata
<<

cmt  = IF_LC:...:break(2), UNLESS_LC:...:last
tmpl = <<:chomp
{LOOP:forest}Tree: {LVAR:tree}, Species: {LVAR:species}
{UNLESS_LC:forest:last}{IF_LC:forest:break(2)}
{END_IF_LC:forest:break(2)}{END_UNLESS_LC:forest:last}{END_LOOP:forest}
<<
out = <<
Tree: trident maple, Species: acer buergerianum
Tree: southern live oak, Species: quercus virginiana

Tree: longleaf pine, Species: pinus palustris
Tree: maidenhair tree, Species: ginkgo biloba

Tree: american beech, Species: fagus grandifolia
Tree: american chestnut, Species: castanea dentata
<<

tmpl = Trees: {LOOP:forest}{IF_LC:last}and {LVAR:tree}{ELSE}{LVAR:tree}, {END_IF_LC:last}{END_LOOP:forest}.
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, and american chestnut.
 cmt = IF_LC:last with ELSE

tmpl = Trees: {LOOP:forest}{IF_LC:last}and {LVAR:tree}{ELSE:last}{LVAR:tree}, {END_IF_LC:last}{END_LOOP:forest}.
 out = Trees: trident maple, southern live oak, longleaf pine, maidenhair tree, american beech, and american chestnut.
 cmt = IF_LC:last with ELSE:last

cmt  = IF_LC:last with ELSE, IF_LC:break(3) with ELSE, UNLESS_LC:last (nested)
tmpl = <<:chomp
Trees: {LOOP:forest}{IF_LC:last}and {LVAR:tree}{ELSE}{LVAR:tree},{IF_LC:break(3)}{UNLESS_LC:last}
{END_UNLESS_LC:last}{ELSE} {END_IF_LC:break(3)}{END_IF_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

cmt  = IF_LC:last with ELSE(named), IF_LC:break(3) with ELSE(named), UNLESS_LC:last (nested)
tmpl = <<:chomp
Trees: {LOOP:forest}{IF_LC:last}and {LVAR:tree}{ELSE:last}{LVAR:tree},{IF_LC:break(3)}{UNLESS_LC:last}
{END_UNLESS_LC:last}{ELSE:break(3)} {END_IF_LC:break(3)}{END_IF_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

# the following shows explicitly which IF belongs to which ELSE ...

cmt  = IF_LC:last with ELSE (explicit), IF_LC:break(3) with ELSE (explicit), UNLESS_LC:last (nested)
tmpl = <<:chomp
Trees: {LOOP:forest}{IF_LC:last}and {LVAR:tree}{ELSE_IF_LC:last}{LVAR:tree},{IF_LC:break(3)}{UNLESS_LC:last}
{END_UNLESS_LC:last}{ELSE_IF_LC:break(3)} {END_IF_LC:break(3)}{END_IF_LC:last}{END_LOOP:forest}.
<<
out = <<:chomp
Trees: trident maple, southern live oak, longleaf pine,
maidenhair tree, american beech, and american chestnut.
<<

#---------------------------------------------------------------------
# IF_LVAR/UNLESS_LVAR with ELSE

tmpl = {LOOP:forest}{IF_LVAR:tree}Yup.{ELSE}Nope.{END_IF_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = IF_LVAR with ELSE, positive

tmpl = {LOOP:forest}{IF_LVAR:tree}Yup.{ELSE:tree}Nope.{END_IF_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = IF_LVAR with ELSE (named), positive

tmpl = {LOOP:forest}{IF_LVAR:tree}Yup.{ELSE_IF_LVAR:tree}Nope.{END_IF_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = IF_LVAR with ELSE (explicit), positive

tmpl = {LOOP:forest}{UNLESS_LVAR:tree}Nope.{ELSE}Yup.{END_UNLESS_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = UNLESS_LVAR with ELSE, positive

tmpl = {LOOP:forest}{UNLESS_LVAR:tree}Nope.{ELSE:tree}Yup.{END_UNLESS_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = UNLESS_LVAR with ELSE (named), positive

tmpl = {LOOP:forest}{UNLESS_LVAR:tree}Nope.{ELSE_UNLESS_LVAR:tree}Yup.{END_UNLESS_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = UNLESS_LVAR with ELSE (explicit), positive

tmpl = {LOOP:forest}{IF_LVAR:lvar_null}Yup.{ELSE}Nope.{END_IF_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = IF_LVAR with ELSE, negative

tmpl = {LOOP:forest}{IF_LVAR:lvar_null}Yup.{ELSE:lvar_null}Nope.{END_IF_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = IF_LVAR with ELSE (named), negative

tmpl = {LOOP:forest}{IF_LVAR:lvar_null}Yup.{ELSE_IF_LVAR:lvar_null}Nope.{END_IF_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = IF_LVAR with ELSE (explicit), negative

tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}Nope.{ELSE}Yup.{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = UNLESS_LVAR with ELSE, negative

tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}Nope.{ELSE:lvar_null}Yup.{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = UNLESS_LVAR with ELSE (named), negative

tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}Nope.{ELSE_UNLESS_LVAR:lvar_null}Yup.{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = UNLESS_LVAR with ELSE (explicit), negative

#---------------------------------------------------------------------
# IF_LVAR/UNLESS_LVAR (no ELSE)

tmpl = {LOOP:forest}{IF_LVAR:tree}Yup.{END_IF_LVAR:tree}{END_LOOP:forest}
 out = Yup.Yup.Yup.Yup.Yup.Yup.
 cmt = IF_LVAR, positive

tmpl = {LOOP:forest}{UNLESS_LVAR:tree}Nope.{END_UNLESS_LVAR:tree}{END_LOOP:forest}
 out = ''  # no else
 cmt = UNLESS_LVAR, positive

tmpl = {LOOP:forest}{IF_LVAR:lvar_null}Yup.{END_IF_LVAR:lvar_null}{END_LOOP:forest}
 out = ''  # no else
 cmt = IF_LVAR, negative

tmpl = {LOOP:forest}{UNLESS_LVAR:lvar_null}Nope.{END_UNLESS_LVAR:lvar_null}{END_LOOP:forest}
 out = Nope.Nope.Nope.Nope.Nope.Nope.
 cmt = UNLESS_LVAR, negative

#---------------------------------------------------------------------
# IF_LOOP/UNLESS_LOOP with ELSE

tmpl = {IF_LOOP:forest}Yup.{ELSE}Nope.{END_IF_LOOP:forest}
 out = Yup.
 cmt = IF_LOOP with ELSE, positive

tmpl = {IF_LOOP:forest}Yup.{ELSE:forest}Nope.{END_IF_LOOP:forest}
 out = Yup.
 cmt = IF_LOOP with ELSE (named), positive

tmpl = {IF_LOOP:forest}Yup.{ELSE_IF_LOOP:forest}Nope.{END_IF_LOOP:forest}
 out = Yup.
 cmt = IF_LOOP with ELSE (explicit), positive

tmpl = {UNLESS_LOOP:forest}Nope.{ELSE}Yup.{END_UNLESS_LOOP:forest}
 out = Yup.
 cmt = UNLESS_LOOP with ELSE, positive

tmpl = {UNLESS_LOOP:forest}Nope.{ELSE:forest}Yup.{END_UNLESS_LOOP:forest}
 out = Yup.
 cmt = UNLESS_LOOP with ELSE (named), positive

tmpl = {UNLESS_LOOP:forest}Nope.{ELSE_UNLESS_LOOP:forest}Yup.{END_UNLESS_LOOP:forest}
 out = Yup.
 cmt = UNLESS_LOOP with ELSE (explicit), positive

tmpl = {IF_LOOP:loop_null}Yup.{ELSE}Nope.{END_IF_LOOP:loop_null}
 out = Nope.
 cmt = IF_LOOP with ELSE, negative

tmpl = {IF_LOOP:loop_null}Yup.{ELSE:loop_null}Nope.{END_IF_LOOP:loop_null}
 out = Nope.
 cmt = IF_LOOP with ELSE (named), negative

tmpl = {IF_LOOP:loop_null}Yup.{ELSE_IF_LOOP:loop_null}Nope.{END_IF_LOOP:loop_null}
 out = Nope.
 cmt = IF_LOOP with ELSE (explicit), negative

tmpl = {UNLESS_LOOP:loop_null}Nope.{ELSE}Yup.{END_UNLESS_LOOP:loop_null}
 out = Nope.
 cmt = UNLESS_LOOP with ELSE, negative

tmpl = {UNLESS_LOOP:loop_null}Nope.{ELSE:loop_null}Yup.{END_UNLESS_LOOP:loop_null}
 out = Nope.
 cmt = UNLESS_LOOP with ELSE (named), negative

tmpl = {UNLESS_LOOP:loop_null}Nope.{ELSE_UNLESS_LOOP:loop_null}Yup.{END_UNLESS_LOOP:loop_null}
 out = Nope.
 cmt = UNLESS_LOOP with ELSE (explicit), negative

#---------------------------------------------------------------------
# IF_LOOP/UNLESS_LOOP (no ELSE)

tmpl = {IF_LOOP:forest}Yup.{END_IF_LOOP:forest}
 out = Yup.
 cmt = IF_LOOP, positive

tmpl = {UNLESS_LOOP:forest}Nope.{END_UNLESS_LOOP:forest}
 out = ''  # no else
 cmt = UNLESS_LOOP, positive

tmpl = {IF_LOOP:loop_null}Yup.{END_IF_LOOP:loop_null}
 out = ''  # no else
 cmt = IF_LOOP, negative

tmpl = {UNLESS_LOOP:loop_null}Nope.{END_UNLESS_LOOP:loop_null}
 out = Nope.
 cmt = UNLESS_LOOP, negative

#---------------------------------------------------------------------
# IF_INI/UNLESS_INI with ELSE

tmpl = {IF_INI:loops:forest}Yup.{ELSE}Nope.{END_IF_INI:loops:forest}
 out = Yup.
 cmt = IF_INI with ELSE, positive

tmpl = {IF_INI:loops:forest}Yup.{ELSE:loops:forest}Nope.{END_IF_INI:loops:forest}
 out = Yup.
 cmt = IF_INI with ELSE (named), positive

tmpl = {IF_INI:loops:forest}Yup.{ELSE_IF_INI:loops:forest}Nope.{END_IF_INI:loops:forest}
 out = Yup.
 cmt = IF_INI with ELSE (explicit), positive

tmpl = {UNLESS_INI:loops:forest}Nope.{ELSE}Yup.{END_UNLESS_INI:loops:forest}
 out = Yup.
 cmt = UNLESS_INI with ELSE, positive

tmpl = {UNLESS_INI:loops:forest}Nope.{ELSE:loops:forest}Yup.{END_UNLESS_INI:loops:forest}
 out = Yup.
 cmt = UNLESS_INI with ELSE (named), positive

tmpl = {UNLESS_INI:loops:forest}Nope.{ELSE_UNLESS_INI:loops:forest}Yup.{END_UNLESS_INI:loops:forest}
 out = Yup.
 cmt = UNLESS_INI with ELSE (explicit), positive

tmpl = {IF_INI:loops:loop_null}Yup.{ELSE}Nope.{END_IF_INI:loops:loop_null}
 out = Nope.
 cmt = IF_INI with ELSE, negative

tmpl = {IF_INI:loops:loop_null}Yup.{ELSE:loops:loop_null}Nope.{END_IF_INI:loops:loop_null}
 out = Nope.
 cmt = IF_INI with ELSE (named), negative

tmpl = {IF_INI:loops:loop_null}Yup.{ELSE_IF_INI:loops:loop_null}Nope.{END_IF_INI:loops:loop_null}
 out = Nope.
 cmt = IF_INI with ELSE (explicit), negative

tmpl = {UNLESS_INI:loops:loop_null}Nope.{ELSE}Yup.{END_UNLESS_INI:loops:loop_null}
 out = Nope.
 cmt = UNLESS_INI with ELSE, negative

tmpl = {UNLESS_INI:loops:loop_null}Nope.{ELSE:loops:loop_null}Yup.{END_UNLESS_INI:loops:loop_null}
 out = Nope.
 cmt = UNLESS_INI with ELSE (named), negative

tmpl = {UNLESS_INI:loops:loop_null}Nope.{ELSE_UNLESS_INI:loops:loop_null}Yup.{END_UNLESS_INI:loops:loop_null}
 out = Nope.
 cmt = UNLESS_INI with ELSE (explicit), negative

tmpl = {IF_INI:loops:forest:0}Yup.{ELSE}Nope.{END_IF_INI:loops:forest:0}
 out = Yup.
 cmt = IF_INI (subscripted) with ELSE, positive

tmpl = {IF_INI:loops:forest:0}Yup.{ELSE:loops:forest:0}Nope.{END_IF_INI:loops:forest:0}
 out = Yup.
 cmt = IF_INI (subscripted) with ELSE (named), positive

tmpl = {IF_INI:loops:forest:0}Yup.{ELSE_IF_INI:loops:forest:0}Nope.{END_IF_INI:loops:forest:0}
 out = Yup.
 cmt = IF_INI (subscripted) with ELSE (explicit), positive

tmpl = {UNLESS_INI:loops:forest:0}Nope.{ELSE}Yup.{END_UNLESS_INI:loops:forest:0}
 out = Yup.
 cmt = UNLESS_INI (subscripted) with ELSE, positive

tmpl = {UNLESS_INI:loops:forest:0}Nope.{ELSE:loops:forest:0}Yup.{END_UNLESS_INI:loops:forest:0}
 out = Yup.
 cmt = UNLESS_INI (subscripted) with ELSE (named), positive

tmpl = {UNLESS_INI:loops:forest:0}Nope.{ELSE_UNLESS_INI:loops:forest:0}Yup.{END_UNLESS_INI:loops:forest:0}
 out = Yup.
 cmt = UNLESS_INI (subscripted) with ELSE (explicit), positive

tmpl = {IF_INI:loops:forest:999}Yup.{ELSE}Nope.{END_IF_INI:loops:forest:999}
 out = Nope.
 cmt = IF_INI (subscripted) with ELSE, negative

tmpl = {IF_INI:loops:forest:999}Yup.{ELSE:loops:forest:999}Nope.{END_IF_INI:loops:forest:999}
 out = Nope.
 cmt = IF_INI (subscripted) with ELSE (named), negative

tmpl = {IF_INI:loops:forest:999}Yup.{ELSE_IF_INI:loops:forest:999}Nope.{END_IF_INI:loops:forest:999}
 out = Nope.
 cmt = IF_INI (subscripted) with ELSE (explicit), negative

tmpl = {UNLESS_INI:loops:forest:999}Nope.{ELSE}Yup.{END_UNLESS_INI:loops:forest:999}
 out = Nope.
 cmt = UNLESS_INI (subscripted) with ELSE, negative

tmpl = {UNLESS_INI:loops:forest:999}Nope.{ELSE:loops:forest:999}Yup.{END_UNLESS_INI:loops:forest:999}
 out = Nope.
 cmt = UNLESS_INI (subscripted) with ELSE (named), negative

tmpl = {UNLESS_INI:loops:forest:999}Nope.{ELSE_UNLESS_INI:loops:forest:999}Yup.{END_UNLESS_INI:loops:forest:999}
 out = Nope.
 cmt = UNLESS_INI (subscripted) with ELSE (explicit), negative

#---------------------------------------------------------------------
# IF_INI/UNLESS_INI (no ELSE)

tmpl = {IF_INI:loops:forest}Yup.{END_IF_INI:loops:forest}
 out = Yup.
 cmt = IF_INI, positive

tmpl = {UNLESS_INI:loops:forest}Nope.{END_UNLESS_INI:loops:forest}
 out = ''  # no else
 cmt = UNLESS_INI, positive

tmpl = {IF_INI:loops:loop_null}Yup.{END_IF_INI:loops:loop_null}
 out = ''  # no else
 cmt = IF_INI, negative

tmpl = {UNLESS_INI:loops:loop_null}Nope.{END_UNLESS_INI:loops:loop_null}
 out = Nope.
 cmt = UNLESS_INI, negative

tmpl = {IF_INI:loops:forest:0}Yup.{END_IF_INI:loops:forest:0}
 out = Yup.
 cmt = IF_INI (subscripted), positive

tmpl = {UNLESS_INI:loops:forest:0}Nope.{END_UNLESS_INI:loops:forest:0}
 out = ''  # no else
 cmt = UNLESS_INI (subscripted), positive

tmpl = {IF_INI:loops:forest:999}Yup.{END_IF_INI:loops:forest:999}
 out = ''  # no else
 cmt = IF_INI (subscripted), negative

tmpl = {UNLESS_INI:loops:forest:999}Nope.{END_UNLESS_INI:loops:forest:999}
 out = Nope.
 cmt = UNLESS_INI (subscripted), negative

#---------------------------------------------------------------------
# IF_VAR/UNLESS_VAR with ELSE

tmpl = {IF_VAR:hey}Yup.{ELSE}Nope.{END_IF_VAR:hey}
 out = Yup.
 cmt = IF_VAR with ELSE, positive

tmpl = {IF_VAR:hey}Yup.{ELSE:hey}Nope.{END_IF_VAR:hey}
 out = Yup.
 cmt = IF_VAR with ELSE (named), positive

tmpl = {IF_VAR:hey}Yup.{ELSE_IF_VAR:hey}Nope.{END_IF_VAR:hey}
 out = Yup.
 cmt = IF_VAR with ELSE (explicit), positive

tmpl = {UNLESS_VAR:hey}Nope.{ELSE}Yup.{END_UNLESS_VAR:hey}
 out = Yup.
 cmt = UNLESS_VAR with ELSE, positive

tmpl = {UNLESS_VAR:hey}Nope.{ELSE:hey}Yup.{END_UNLESS_VAR:hey}
 out = Yup.
 cmt = UNLESS_VAR with ELSE (named), positive

tmpl = {UNLESS_VAR:hey}Nope.{ELSE_UNLESS_VAR:hey}Yup.{END_UNLESS_VAR:hey}
 out = Yup.
 cmt = UNLESS_VAR with ELSE (explicit), positive

tmpl = {IF_VAR:test_null}Yup.{ELSE}Nope.{END_IF_VAR:test_null}
 out = Nope.
 cmt = IF_VAR with ELSE, negative

tmpl = {IF_VAR:test_null}Yup.{ELSE:test_null}Nope.{END_IF_VAR:test_null}
 out = Nope.
 cmt = IF_VAR with ELSE (named), negative

tmpl = {IF_VAR:test_null}Yup.{ELSE_IF_VAR:test_null}Nope.{END_IF_VAR:test_null}
 out = Nope.
 cmt = IF_VAR with ELSE (explicit), negative

tmpl = {UNLESS_VAR:test_null}Nope.{ELSE}Yup.{END_UNLESS_VAR:test_null}
 out = Nope.
 cmt = UNLESS_VAR with ELSE, negative

tmpl = {UNLESS_VAR:test_null}Nope.{ELSE:test_null}Yup.{END_UNLESS_VAR:test_null}
 out = Nope.
 cmt = UNLESS_VAR with ELSE (named), negative

tmpl = {UNLESS_VAR:test_null}Nope.{ELSE_UNLESS_VAR:test_null}Yup.{END_UNLESS_VAR:test_null}
 out = Nope.
 cmt = UNLESS_VAR with ELSE (explicit), negative

#---------------------------------------------------------------------
# IF_VAR/UNLESS_VAR (no ELSE)

tmpl = {IF_VAR:hey}Yup.{END_IF_VAR:hey}
 out = Yup.
 cmt = IF_VAR, positive

tmpl = {UNLESS_VAR:hey}Nope.{END_UNLESS_VAR:hey}
 out = ''  # no else
 cmt = UNLESS_VAR, positive

tmpl = {IF_VAR:test_null}Yup.{END_IF_VAR:test_null}
 out = ''  # no else
 cmt = IF_VAR, negative

tmpl = {UNLESS_VAR:test_null}Nope.{END_UNLESS_VAR:test_null}
 out = Nope.
 cmt = UNLESS_VAR, negative

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
