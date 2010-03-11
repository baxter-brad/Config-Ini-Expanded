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

[samples]

hello = Hello.
a = A
b = B
c = C

[loops]

A = <<:json
[{
    A: "Alpha",
    B: "Beta"
}]
<<

B = <<:json
[{ B: "Beta (B)" }]
<<

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
# Order of processing:

comment = <<

Note, prior to version 1.04, this comment started out with this
paragraph ...

This comment attempts to explain (and the following tests attempt to
illustrate) those cases when an {ELSE} tag inside nested {IF...} and
{UNLESS...} blocks must be explicitly qualified to disambiguate the
ELSE's beginning tag.

... and went on to explain that unqualified {ELSE} tags would not
always be interpreted correctly.

But starting with version 1.04, unqualified {ELSE} tags are properly
disambiguated, so it's now more safe to use them.  That is, the module
will know which begin tag it belongs to, though for human consumption,
it still may be a good idea to make them explicit.

The tests below are much like they were prior to version 1.04, but
where the comments said "ELSE is wrong", they now say "ELSE is okay",
and the output is changed to match the result for the same template
with the ELSE fully qualified.  (And many other comments have been
appropriately changed.)

Starting with version 1.09, you can "partially qualify" an {ELSE} by
giving it just the name of the enclosing IF/UNLESS (without the _IF
or _UNLESS part).  This was added because {ELSE_IF...} looks too much
like an "elsif" operation, when it's not that at all.  For example,
instead of
    {IF_VAR:boy}...{ELSE_IF_VAR:boy}...{END_IF_VAR:boy}  (fully qualified)
or
    {IF_VAR:boy}...{ELSE}...{END_IF_VAR:boy} (not qualified)
you can write
    {IF_VAR:boy}...{ELSE:boy}...{END_IF_VAR:boy} (partially qualified)

This has the advantage of avoiding {ELSE_IF...}, which might imply
confusing logic, and of avoiding {ELSE}, which lacks matching clues
for the programmer, and of letting the program tell you if your
choice of {ELSE:name} is wrong (i.e., if "name" is *not* the name of
the enclosing IF/UNLESS).

<<

#---------------------------------------------------------------------
# examples from above comments (prior to version 1.04)

tmpl = ... {IF_VAR:a}A{END_IF_VAR:a} ... {IF_VAR:a}{VAR:a}{END_IF_VAR:a} ...
 out = ... A ... 1 ...
 cmt = example in comment, IF_VAR:a, IF_VAR:a (non-greedy matching)

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, IF_VAR:b, ELSE is okay

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, IF_VAR:b, ELSE is given a name

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, IF_VAR:b, ELSE is fully qualified

#---------------------------------------------------------------------
# more examples showing nested {ELSE} for same type of begin tag, e.g.
# IF_VAR...IF_VAR, UNLESS_VAR...UNLESS_VAR, etc.

# IF_VAR   UNLESS_VAR

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = IF_VAR:a, IF_VAR:b, ELSE is okay

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = IF_VAR:a, IF_VAR:b, ELSE (given a name)

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = IF_VAR:a, IF_VAR:b, ELSE (fully qualified)

tmpl = {UNLESS_VAR:a}no A{ELSE}A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{END_UNLESS_VAR:a}
 out = AB
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE is okay

tmpl = {UNLESS_VAR:a}no A{ELSE:a}A{UNLESS_VAR:b}no B{ELSE:b}B{END_UNLESS_VAR:b}{END_UNLESS_VAR:a}
 out = AB
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE (given a name)

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE is okay

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE:b}B{END_UNLESS_VAR:b}{ELSE:a}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE (given a name)

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE:b}B{END_UNLESS_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE (one is given a name)

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE_UNLESS_VAR:b}B{END_UNLESS_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_INI   UNLESS_INI

# side note: ':join:chomp:indented' will convert the heredoc into one
# long line like the tmpl's above, letting us indent for clarity,
# but retain simpler output for comparisons

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {IF_INI:samples:b}
        B
    {ELSE}
        no B
    {END_IF_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, IF_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {IF_INI:samples:b}
        B
    {ELSE:samples:b}
        no B
    {END_IF_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, IF_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {IF_INI:samples:b}
        B
    {ELSE_IF_INI:samples:b}
        no B
    {END_IF_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, IF_INI:...:b, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
{ELSE}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE}
        B
    {END_UNLESS_INI:samples:b}
{END_UNLESS_INI:samples:a}
<<
out = AB
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
{ELSE:samples:a}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{END_UNLESS_INI:samples:a}
<<
out = AB
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE is okay now

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE:samples:a}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE_UNLESS_INI:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_LOOP  UNLESS_LOOP    

# (note that LVAR:B is from LOOP:A)

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {IF_LOOP:B}
            {LVAR:B}
        {ELSE}
            no Beta
        {END_IF_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, IF_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {IF_LOOP:B}
            {LVAR:B}
        {ELSE:B}
            no Beta
        {END_IF_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, IF_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {IF_LOOP:B}
            {LVAR:B}
        {ELSE_IF_LOOP:B}
            no B
        {END_IF_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, IF_LOOP:B, ELSE (fully qualified)

# (now LVAR:B is from LOOP:B)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
{ELSE}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LOOP:B}
            no Beta
        {ELSE}
            {LOOP:B}
                {LVAR:B}
            {END_LOOP:B}
        {END_UNLESS_LOOP:B}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = AlphaBeta (B)
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
{ELSE:A}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LOOP:B}
            no Beta
        {ELSE:B}
            {LOOP:B}
                {LVAR:B}
            {END_LOOP:B}
        {END_UNLESS_LOOP:B}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = AlphaBeta (B)
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LOOP:B}
        no Beta
    {ELSE}
        {LOOP:B}
            {LVAR:B}
        {END_LOOP:B}
    {END_UNLESS_LOOP:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LOOP:B}
        no Beta
    {ELSE:B}
        {LOOP:B}
            {LVAR:B}
        {END_LOOP:B}
    {END_UNLESS_LOOP:B}
{ELSE:A}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LOOP:B}
        no Beta
    {ELSE:B}
        {LOOP:B}
            {LVAR:B}
        {END_LOOP:B}
    {END_UNLESS_LOOP:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LOOP:B}
        no Beta
    {ELSE_UNLESS_LOOP:B}
        {LOOP:B}
            {LVAR:B}
        {END_LOOP:B}
    {END_UNLESS_LOOP:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_LVAR  UNLESS_LVAR

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {IF_LVAR:B}
            {LVAR:B}
        {ELSE}
            no Beta
        {END_IF_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, IF_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {IF_LVAR:B}
            {LVAR:B}
        {ELSE:B}
            no Beta
        {END_IF_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, IF_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {IF_LVAR:B}
            {LVAR:B}
        {ELSE_IF_LVAR:B}
            no Beta
        {END_IF_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, IF_LVAR:B, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
    {ELSE}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
    {ELSE:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LVAR:B}
            no Beta
        {ELSE}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LVAR:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {ELSE:A}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LVAR:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LVAR:B}
            no Beta
        {ELSE_UNLESS_LVAR:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_LC    UNLESS_LC

# note: first and last are both true here, because there's only one
# element in the loop ... that's helpful for these examples

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LC:last}
            last
        {ELSE}
            not last
        {END_IF_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, IF_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LC:last}
            last
        {ELSE:last}
            not last
        {END_IF_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, IF_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LC:last}
            last
        {ELSE_IF_LC:last}
            not last
        {END_IF_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, IF_LC:last, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
    {ELSE}
        first
        {UNLESS_LC:last}
            not last
        {ELSE}
            last
        {END_UNLESS_LC:last}
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
    {ELSE:first}
        first
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LC:last}
            not last
        {ELSE}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LC:last}
            not last
        {ELSE_UNLESS_LC:last}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# more examples ...

# (pre-version-1.04 comment deleted)

tmpl = {IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, UNLESS_VAR:b, ELSE is okay

tmpl = {IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE:b}B{END_UNLESS_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, UNLESS_VAR:b, ELSE (given a name)

tmpl = {IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE_UNLESS_VAR:b}B{END_UNLESS_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, UNLESS_VAR:b, ELSE (fully qualified)

#---------------------------------------------------------------------
# IF_VAR   UNLESS_VAR

tmpl = <<:join:chomp:indented
{IF_VAR:a}
    A
    {UNLESS_VAR:b}
        no B
    {ELSE}
        B
    {END_UNLESS_VAR:b}
{END_IF_VAR:a}
<<
out = AB
cmt = IF_VAR:a, UNLESS_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_VAR:a}
    A
    {UNLESS_VAR:b}
        no B
    {ELSE:b}
        B
    {END_UNLESS_VAR:b}
{END_IF_VAR:a}
<<
out = AB
cmt = IF_VAR:a, UNLESS_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_VAR:a}
    A
    {UNLESS_VAR:b}
        no B
    {ELSE_UNLESS_VAR:b}
        B
    {END_UNLESS_VAR:b}
{END_IF_VAR:a}
<<
out = AB
cmt = IF_VAR:a, UNLESS_VAR:b, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
{ELSE}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE}
        B
    {END_UNLESS_INI:samples:b}
{END_UNLESS_VAR:a}
<<
out = AB
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
{ELSE:a}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{END_UNLESS_VAR:a}
<<
out = AB
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_VAR:a}
<<
out = A
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE:a}
    A
{END_UNLESS_VAR:a}
<<
out = A
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_VAR:a}
<<
out = A
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{UNLESS_VAR:a}
    no A
    {UNLESS_INI:samples:b}
        no B
    {ELSE_UNLESS_INI:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_VAR:a}
<<
out = A
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_INI   UNLESS_INI

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE}
        B
    {END_UNLESS_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, UNLESS_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, UNLESS_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {UNLESS_INI:samples:b}
        no B
    {ELSE_UNLESS_INI:samples:b}
        B
    {END_UNLESS_INI:samples:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, UNLESS_INI:...:b, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
{ELSE}
    A
    {UNLESS_LOOP:B}
        no B
    {ELSE}
        B
    {END_UNLESS_LOOP:B}
{END_UNLESS_INI:samples:a}
<<
out = AB
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
{ELSE:samples:a}
    A
    {UNLESS_LOOP:B}
        no B
    {ELSE:B}
        B
    {END_UNLESS_LOOP:B}
{END_UNLESS_INI:samples:a}
<<
out = AB
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_LOOP:B}
        no B
    {ELSE}
        B
    {END_UNLESS_LOOP:B}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_LOOP:B}
        no B
    {ELSE:B}
        B
    {END_UNLESS_LOOP:B}
{ELSE:samples:a}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_LOOP:B}
        no B
    {ELSE:B}
        B
    {END_UNLESS_LOOP:B}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_LOOP:B}
        no B
    {ELSE_UNLESS_LOOP:B}
        B
    {END_UNLESS_LOOP:B}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_LOOP  UNLESS_LOOP    

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LOOP:B}
            no Beta
        {ELSE}
            {LVAR:B}
        {END_UNLESS_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LOOP:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, UNLESS_LOOP:B, ELSE (given a name)

# (LVAR:B is from LOOP:A)

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LOOP:B}
            no B
        {ELSE_UNLESS_LOOP:B}
            {LVAR:B}
        {END_UNLESS_LOOP:B}
    {END_LOOP:A}
{END_IF_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LOOP:A, UNLESS_LOOP:B, ELSE is right

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
{ELSE}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = AlphaBeta
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
{ELSE}
    {LOOP:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = AlphaBeta
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LVAR:B}
        no Beta
    {ELSE}
        {LVAR:B}
    {END_UNLESS_LVAR:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LVAR:B}
        no Beta
    {ELSE:B}
        {LVAR:B}
    {END_UNLESS_LVAR:B}
{ELSE:A}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no Alpha
    {UNLESS_LVAR:B}
        no Beta
    {ELSE_UNLESS_LVAR:B}
        {LVAR:B}
    {END_UNLESS_LVAR:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE (fully qualified)

#---------------------------------------------------------------------
# IF_LVAR  UNLESS_LVAR

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        {LVAR:A}
        {UNLESS_LVAR:B}
            no Beta
        {ELSE_UNLESS_LVAR:B}
            {LVAR:B}
        {END_UNLESS_LVAR:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AlphaBeta
cmt = IF_LVAR:A, UNLESS_LVAR:B, ELSE (fully qualified)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
    {ELSE}
        {LVAR:A}
        {UNLESS_LC:last}
            not last
        {ELSE}
            last
        {END_UNLESS_LC:last}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alphalast
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
    {ELSE:A}
        {LVAR:A}
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alphalast
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LC:last}
            not last
        {ELSE}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {ELSE:A}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE (one is given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no Alpha
        {UNLESS_LC:last}
            not last
        {ELSE_UNLESS_LC:last}
            last
        {END_UNLESS_LC:last}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE (one is fully qualified)

#---------------------------------------------------------------------
# IF_LC    UNLESS_LC

# note: first and last are both true here, because there's only one
# element in the loop ... that's helpful for these examples

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {UNLESS_LC:last}
            not last
        {ELSE}
            last
        {END_UNLESS_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, UNLESS_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {UNLESS_LC:last}
            not last
        {ELSE:last}
            last
        {END_UNLESS_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, UNLESS_LC:last, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {UNLESS_LC:last}
            not last
        {ELSE_UNLESS_LC:last}
            last
        {END_UNLESS_LC:last}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstlast
cmt = IF_LC:first, UNLESS_LC:last, ELSE (fully qualified)

#---------------------------------------------------------------------
# more examples ...

# (pre-version-1.04 comment deleted)

#---------------------------------------------------------------------
# example from above comments

tmpl = {UNLESS_VAR:a}no A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = example in comment, UNLESS_VAR:a, IF_VAR:b, ELSE is okay

tmpl = {UNLESS_VAR:a}no A{IF_VAR:b}B{ELSE:b}no B{END_IF_VAR:b}{ELSE:a}A{END_UNLESS_VAR:a}
 out = A
 cmt = example in comment, UNLESS_VAR:a, IF_VAR:b, ELSE (given a name)

#---------------------------------------------------------------------
# IF_INI   UNLESS_INI

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {IF_INI:samples:b}
        B
    {ELSE}
        no B
    {END_IF_INI:samples:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, IF_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {IF_INI:samples:b}
        B
    {ELSE:samples:b}
        no B
    {END_IF_INI:samples:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, IF_INI:...:b, ELSE (given a name)

#---------------------------------------------------------------------
# IF_LOOP  UNLESS_LOOP    

# (note that LVAR:B is from LOOP:A)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {IF_LOOP:B}
        {LVAR:B}
    {ELSE}
        no Beta
    {END_IF_LOOP:B}
{ELSE}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, IF_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {IF_LOOP:B}
        {LVAR:B}
    {ELSE:B}
        no Beta
    {END_IF_LOOP:B}
{ELSE:A}
    {LOOP:A}
        {LVAR:A}
    {END_LOOP:A}
{END_UNLESS_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LOOP:A, IF_LOOP:B, ELSE (given a name)

#---------------------------------------------------------------------
# IF_LVAR  UNLESS_LVAR

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {IF_LVAR:B}
            {LVAR:B}
        {ELSE}
            no Beta
        {END_IF_LVAR:B}
    {ELSE}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, IF_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {IF_LVAR:B}
            {LVAR:B}
        {ELSE:B}
            no Beta
        {END_IF_LVAR:B}
    {ELSE:A}
        {LVAR:A}
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = Alpha
cmt = UNLESS_LVAR:A, IF_LVAR:B, ELSE (given a name)

#---------------------------------------------------------------------
# IF_LC    UNLESS_LC

# note: first and last are both true here, because there's only one
# element in the loop ... that's helpful for these examples

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {IF_LC:last}
            last
        {ELSE}
            not last
        {END_IF_LC:last}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, IF_LC:last, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {IF_LC:last}
            last
        {ELSE:last}
            not last
        {END_IF_LC:last}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:first, IF_LC:last, ELSE (given a name)

#---------------------------------------------------------------------
# more examples re: order of processing ...
#
#     IF_VAR   UNLESS_VAR
#     IF_INI   UNLESS_INI
#     IF_LOOP  UNLESS_LOOP    
#     IF_LVAR  UNLESS_LVAR
#     IF_LC    UNLESS_LC
#

comment = <<

Note: the comments prior to version 1.04 started like this ...

"Permutations that help to prove the order:"

But the order of processing makes no difference now.
However, I'm leaving these tests in place, because they do what
they were intended to do, i.e., to show that later changes to
the module do not change how these constructs work.

<<

#---------------------------------------------------------------------
# IF...

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {IF_VAR:b}
        B
    {ELSE}
        no B
    {END_IF_VAR:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, IF_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_INI:samples:a}
    A
    {IF_VAR:b}
        B
    {ELSE:b}
        no B
    {END_IF_VAR:b}
{END_IF_INI:samples:a}
<<
out = AB
cmt = IF_INI:...:a, IF_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    A
    {IF_INI:samples:b}
        B
    {ELSE}
        no B
    {END_IF_INI:samples:b}
{END_IF_LOOP:A}
<<
out = AB
cmt = IF_LOOP:A, IF_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    A
    {IF_INI:samples:b}
        B
    {ELSE:samples:b}
        no B
    {END_IF_INI:samples:b}
{END_IF_LOOP:A}
<<
out = AB
cmt = IF_LOOP:A, IF_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_LOOP:B}
            B
        {ELSE}
            no B
        {END_IF_LOOP:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_LOOP:B}
            B
        {ELSE:B}
            no B
        {END_IF_LOOP:B}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LVAR:B}
            B
        {ELSE}
            no B
        {END_IF_LVAR:B}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LVAR:B}
            B
        {ELSE:B}
            no B
        {END_IF_LVAR:B}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    A
    {IF_VAR:b}
        B
    {ELSE}
        no B
    {END_IF_VAR:b}
{END_IF_LOOP:A}
<<
out = AB
cmt = IF_LOOP:A, IF_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{IF_LOOP:A}
    A
    {IF_VAR:b}
        B
    {ELSE:b}
        no B
    {END_IF_VAR:b}
{END_IF_LOOP:A}
<<
out = AB
cmt = IF_LOOP:A, IF_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_INI:samples:b}
            B
        {ELSE}
            no B
        {END_IF_INI:samples:b}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_INI:samples:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_INI:samples:b}
            B
        {ELSE:samples:b}
            no B
        {END_IF_INI:samples:b}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_INI:samples:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LOOP:B}
            B
        {ELSE}
            no B
        {END_IF_LOOP:B}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_LOOP:B}
            B
        {ELSE:B}
            no B
        {END_IF_LOOP:B}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_VAR:b}
            B
        {ELSE}
            no B
        {END_IF_VAR:b}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LVAR:A}
        A
        {IF_VAR:b}
            B
        {ELSE:b}
            no B
        {END_IF_VAR:b}
    {END_IF_LVAR:A}
{END_LOOP:A}
<<
out = AB
cmt = IF_LVAR:A, IF_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_INI:samples:b}
            B
        {ELSE}
            no B
        {END_IF_INI:samples:b}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_INI:samples:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_INI:samples:b}
            B
        {ELSE:samples:b}
            no B
        {END_IF_INI:samples:b}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_INI:samples:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_VAR:b}
            B
        {ELSE}
            no B
        {END_IF_VAR:b}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {IF_LC:first}
        first
        {IF_VAR:b}
            B
        {ELSE:b}
            no B
        {END_IF_VAR:b}
    {END_IF_LC:first}
{END_LOOP:A}
<<
out = firstB
cmt = IF_LC:A, IF_VAR:b, ELSE (given a name)

#---------------------------------------------------------------------
# UNLESS...

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_VAR:b}
        B
    {ELSE}
        no B
    {END_UNLESS_VAR:b}
{ELSE}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, UNLESS_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_INI:samples:a}
    no A
    {UNLESS_VAR:b}
        B
    {ELSE:b}
        no B
    {END_UNLESS_VAR:b}
{ELSE:samples:a}
    A
{END_UNLESS_INI:samples:a}
<<
out = A
cmt = UNLESS_INI:...:a, UNLESS_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {UNLESS_INI:samples:b}
        B
    {ELSE}
        no B
    {END_UNLESS_INI:samples:b}
{ELSE}
    A
{END_UNLESS_LOOP:A}
<<
out = A
cmt = UNLESS_LOOP:A, UNLESS_INI:...:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {UNLESS_INI:samples:b}
        B
    {ELSE:samples:b}
        no B
    {END_UNLESS_INI:samples:b}
{ELSE:A}
    A
{END_UNLESS_LOOP:A}
<<
out = A
cmt = UNLESS_LOOP:A, UNLESS_INI:...:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_LOOP:B}
            B
        {ELSE}
            no B
        {END_UNLESS_LOOP:B}
    {ELSE}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_LOOP:B}
            B
        {ELSE:B}
            no B
        {END_UNLESS_LOOP:B}
    {ELSE:A}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LVAR:B}
            B
        {ELSE}
            no B
        {END_UNLESS_LVAR:B}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_LVAR:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LVAR:B}
            B
        {ELSE:B}
            no B
        {END_UNLESS_LVAR:B}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_LVAR:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {UNLESS_VAR:b}
        B
    {ELSE}
        no B
    {END_UNLESS_VAR:b}
{ELSE}
    A
{END_UNLESS_LOOP:A}
<<
out = A
cmt = UNLESS_LOOP:A, UNLESS_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{UNLESS_LOOP:A}
    no A
    {UNLESS_VAR:b}
        B
    {ELSE:b}
        no B
    {END_UNLESS_VAR:b}
{ELSE:A}
    A
{END_UNLESS_LOOP:A}
<<
out = A
cmt = UNLESS_LOOP:A, UNLESS_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_INI:samples:b}
            B
        {ELSE}
            no B
        {END_UNLESS_INI:samples:b}
    {ELSE}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_INI:samples:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_INI:samples:b}
            B
        {ELSE:samples:b}
            no B
        {END_UNLESS_INI:samples:b}
    {ELSE:A}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_INI:samples:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LOOP:B}
            B
        {ELSE}
            no B
        {END_UNLESS_LOOP:B}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_LOOP:B, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_LOOP:B}
            B
        {ELSE:B}
            no B
        {END_UNLESS_LOOP:B}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_LOOP:B, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_VAR:b}
            B
        {ELSE}
            no B
        {END_UNLESS_VAR:b}
    {ELSE}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LVAR:A}
        no A
        {UNLESS_VAR:b}
            B
        {ELSE:b}
            no B
        {END_UNLESS_VAR:b}
    {ELSE:A}
        A
    {END_UNLESS_LVAR:A}
{END_LOOP:A}
<<
out = A
cmt = UNLESS_LVAR:A, UNLESS_VAR:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_INI:samples:b}
            B
        {ELSE}
            no B
        {END_UNLESS_INI:samples:b}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_INI:samples:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_INI:samples:b}
            B
        {ELSE:samples:b}
            no B
        {END_UNLESS_INI:samples:b}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_INI:samples:b, ELSE (given a name)

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_VAR:b}
            B
        {ELSE}
            no B
        {END_UNLESS_VAR:b}
    {ELSE}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_VAR:b, ELSE is okay

tmpl = <<:join:chomp:indented
{LOOP:A}
    {UNLESS_LC:first}
        not first
        {UNLESS_VAR:b}
            B
        {ELSE:b}
            no B
        {END_UNLESS_VAR:b}
    {ELSE:first}
        first
    {END_UNLESS_LC:first}
{END_LOOP:A}
<<
out = first
cmt = UNLESS_LC:A, UNLESS_VAR:b, ELSE (given a name)

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

$ini->set_var( hey => "Hey.", a => 1, b => 2, c => 3 );

$ini->set_loop(
        forest  => $ini->get( loops => 'forest'  ),
        A       => $ini->get( loops => 'A'       ),
        B       => $ini->get( loops => 'B'       ),
    );

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
