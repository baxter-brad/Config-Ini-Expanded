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

[to_test]

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
  },
  { tree:      "chinese juniper",
    species:   "juniperus chinensis",
    genus:     "juniperus",
    family:    "cupressaceae",
    order:     "pinales"
  },
  { tree:      "florida yew",
    species:   "taxus floridana",
    genus:     "taxus",
    family:    "taxaceae",
    order:     "pinales"
  },
  { tree:      "joshua tree",
    species:   "yucca brevifolia",
    genus:     "yucca",
    family:    "agavaceae",
    order:     "asparagales"
  }
]
<<

order = <<:json
[
{ order_name: "Asparagales",
  order_family: [  
  { family_name: "Agavaceae",
    family_genus: [
    { genus_name: "Yucca",
      genus_species: [
        { tree: "joshua tree", species: "yucca brevifolia", genus: "yucca", family: "agavaceae", order: "asparagales" }
      ] }
    ] }
  ] },
{ order_name: "Fagales",
  order_family: [
  { family_name: "Fagaceae",
    family_genus: [
    { genus_name: "Castanea",
      genus_species: [
      { tree: "american chestnut", order: "fagales", family: "fagaceae", genus: "castanea", species: "castanea dentata" }
    ] },
    { genus_name: "Fagus",
      genus_species: [
      { tree: "american beech", order: "fagales", family: "fagaceae", genus: "fagus", species: "fagus grandifolia" }
    ] },
    { genus_name: "Quercus",
      genus_species: [
      { tree: "southern live oak", order: "fagales", family: "fagaceae", genus: "quercus", species: "quercus virginiana" }
      ] }
    ] }
  ] },
{ order_name: "Ginkgoales",
  order_family: [
  { family_name: "Ginkgoaceae",
    family_genus: [
    { genus_name: "Gingkgo",
      genus_species: [
      { tree: "maidenhair tree", order: "ginkgoales", family: "ginkgoaceae", genus: "ginkgo", species: "ginkgo biloba" }
      ] }
    ] }
  ] },
{ order_name: "Pinales",
  order_family: [
  { family_name: "Cupressaceae",
    family_genus: [
    { genus_name: "Juniperus",
      genus_species: [
      { tree: "chinese juniper", species: "juniperus chinensis", genus: "juniperus", family: "cupressaceae", order: "pinales" }
      ] }
    ] },
  { family_name: "Pinaceae",
    family_genus: [
    { genus_name: "Pinus",
      genus_species: [
      { tree: "longleaf pine", order: "pinales", family: "pinaceae", genus: "pinus", species: "pinus palustris" }
      ] }
    ] },
  { family_name: "Taxaceae",
    family_genus: [
    { genus_name: "Taxus",
      genus_species: [
      { tree: "florida yew", species: "taxus floridana", genus: "taxus", family: "taxaceae", order: "pinales" }
      ] }
    ] }
  ] },
{ order_name: "Spapindales",
  order_family: [
  { family_name: "Aceraceae",
    family_genus: [
    { genus_name: "Acer",
      genus_species: [
      { tree: "trident maple", order: "sapindales", family: "aceraceae", genus: "acer", species: "acer buergerianum" }
      ] }
    ] }
  ] }
]
<<

[tests]

#---------------------------------------------------------------------
# typical report loop

cmt  = Forest LOOP
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
Tree: chinese juniper, Species: juniperus chinensis, Genus: juniperus, Family: cupressaceae, Order: pinales
Tree: florida yew, Species: taxus floridana, Genus: taxus, Family: taxaceae, Order: pinales
Tree: joshua tree, Species: yucca brevifolia, Genus: yucca, Family: agavaceae, Order: asparagales
<<

#---------------------------------------------------------------------
# typical nested multiple loops

cmt  = Order LOOP, nested
tmpl = <<:chomp
{LOOP:order}{LVAR:order_name}:{LOOP:order_family}
    {LVAR:family_name}:{LOOP:family_genus}
        {LVAR:genus_name}:{LOOP:genus_species}
            Tree: {LVAR:tree}, Species: {LVAR:species}, Genus: {LVAR:genus}, Family: {LVAR:family}, Order: {LVAR:order}{END_LOOP:genus_species}{END_LOOP:family_genus}{END_LOOP:order_family}
{END_LOOP:order}
<<

out = <<
Asparagales:
    Agavaceae:
        Yucca:
            Tree: joshua tree, Species: yucca brevifolia, Genus: yucca, Family: agavaceae, Order: asparagales
Fagales:
    Fagaceae:
        Castanea:
            Tree: american chestnut, Species: castanea dentata, Genus: castanea, Family: fagaceae, Order: fagales
        Fagus:
            Tree: american beech, Species: fagus grandifolia, Genus: fagus, Family: fagaceae, Order: fagales
        Quercus:
            Tree: southern live oak, Species: quercus virginiana, Genus: quercus, Family: fagaceae, Order: fagales
Ginkgoales:
    Ginkgoaceae:
        Gingkgo:
            Tree: maidenhair tree, Species: ginkgo biloba, Genus: ginkgo, Family: ginkgoaceae, Order: ginkgoales
Pinales:
    Cupressaceae:
        Juniperus:
            Tree: chinese juniper, Species: juniperus chinensis, Genus: juniperus, Family: cupressaceae, Order: pinales
    Pinaceae:
        Pinus:
            Tree: longleaf pine, Species: pinus palustris, Genus: pinus, Family: pinaceae, Order: pinales
    Taxaceae:
        Taxus:
            Tree: florida yew, Species: taxus floridana, Genus: taxus, Family: taxaceae, Order: pinales
Spapindales:
    Aceraceae:
        Acer:
            Tree: trident maple, Species: acer buergerianum, Genus: acer, Family: aceraceae, Order: sapindales
<<

#---------------------------------------------------------------------
# nested multiple loops, using inheritance to display from parents
# that is, all of the LVAR's from the initial loops are displayed
# inside the genus_species loop

cmt  = Order LOOP, inherited
tmpl = <<:chomp
{LOOP:order}{LOOP:order_family}{LOOP:family_genus}{LOOP:genus_species}{LVAR:order_name}, {LVAR:family_name}, {LVAR:genus_name}, Tree: {LVAR:tree}, Species: {LVAR:species}, Genus: {LVAR:genus}, Family: {LVAR:family}, Order: {LVAR:order}
{END_LOOP:genus_species}{END_LOOP:family_genus}{END_LOOP:order_family}{END_LOOP:order}
<<

out = <<
Asparagales, Agavaceae, Yucca, Tree: joshua tree, Species: yucca brevifolia, Genus: yucca, Family: agavaceae, Order: asparagales
Fagales, Fagaceae, Castanea, Tree: american chestnut, Species: castanea dentata, Genus: castanea, Family: fagaceae, Order: fagales
Fagales, Fagaceae, Fagus, Tree: american beech, Species: fagus grandifolia, Genus: fagus, Family: fagaceae, Order: fagales
Fagales, Fagaceae, Quercus, Tree: southern live oak, Species: quercus virginiana, Genus: quercus, Family: fagaceae, Order: fagales
Ginkgoales, Ginkgoaceae, Gingkgo, Tree: maidenhair tree, Species: ginkgo biloba, Genus: ginkgo, Family: ginkgoaceae, Order: ginkgoales
Pinales, Cupressaceae, Juniperus, Tree: chinese juniper, Species: juniperus chinensis, Genus: juniperus, Family: cupressaceae, Order: pinales
Pinales, Pinaceae, Pinus, Tree: longleaf pine, Species: pinus palustris, Genus: pinus, Family: pinaceae, Order: pinales
Pinales, Taxaceae, Taxus, Tree: florida yew, Species: taxus floridana, Genus: taxus, Family: taxaceae, Order: pinales
Spapindales, Aceraceae, Acer, Tree: trident maple, Species: acer buergerianum, Genus: acer, Family: aceraceae, Order: sapindales
<<

#---------------------------------------------------------------------
# making sure the innermost loop's lvars trump the out loops'

# These are designed to show that, first, "name" comes from the
# child loop, even though "name" also appears in the parent and
# grandparent, then "Name" comes from the parent (it's not in the
# child) and not from the grandparent's "Name", and finally, "NAME"
# comes from the grandparent, because it does not appear in the child
# or parent.

[to_test]

grandparent = <<:json
[
  { name: "grandparent",
    parent: [
    { name: "parent",
      child: [
      { name: "self" }
      ]
    }
    ]
  }
]
<<

grandparent = <<:json
[
  { Name: "grandparent",
    parent: [
    { Name: "parent",
      child: [
      { name: "self" }
      ]
    }
    ]
  }
]
<<

grandparent = <<:json
[
  { NAME: "grandparent",
    parent: [
    { Name: "parent",
      child: [
      { name: "self" }
      ]
    }
    ]
  }
]
<<

[tests]

cmt  = Self LOOP, from innermost
tmpl = <<
{LOOP:grandparent1}{LOOP:parent}{LOOP:child}{LVAR:name}{END_LOOP:child}{END_LOOP:parent}{END_LOOP:grandparent1}
<<
out = <<
self
<<

cmt  = Parent LOOP, from parent
tmpl = <<
{LOOP:grandparent2}{LOOP:parent}{LOOP:child}{LVAR:Name}{END_LOOP:child}{END_LOOP:parent}{END_LOOP:grandparent2}
<<
out = <<
parent
<<

cmt  = Grandparent LOOP, from grandparent
tmpl = <<
{LOOP:grandparent3}{LOOP:parent}{LOOP:child}{LVAR:NAME}{END_LOOP:child}{END_LOOP:parent}{END_LOOP:grandparent3}
<<
out = <<
grandparent
<<

# this loop shows that you can get an lvar
# from a specifically named ancestor loop

cmt  = Self LOOP, explicitly qualified lvar names
tmpl = <<
{LOOP:grandparent1}{LOOP:parent}{LOOP:child}Granddad:{LVAR:grandparent1:name}, Dad:{LVAR:parent:name}, Me:{LVAR:name}{END_LOOP:child}{END_LOOP:parent}{END_LOOP:grandparent1}
<<
out = <<
Granddad:grandparent, Dad:parent, Me:self
<<

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

$ini->set_var( hey => "Hey.", a => 1, b => 2, c => 3 );

$ini->set_loop(
        forest       => $ini->get( to_test => 'forest'         ),
        order        => $ini->get( to_test => 'order'          ),
        grandparent1 => $ini->get( to_test => 'grandparent', 0 ),
        grandparent2 => $ini->get( to_test => 'grandparent', 1 ),
        grandparent3 => $ini->get( to_test => 'grandparent', 2 ),
    );

for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    my $output  = $ini->get_expanded( tests => 'tmpl', $occ );
    my $wanted  = $ini->get(          tests => 'out',  $occ );
    my $comment = $ini->get(          tests => 'cmt',  $occ );

    is( $output, $wanted, $comment );
}

__END__
