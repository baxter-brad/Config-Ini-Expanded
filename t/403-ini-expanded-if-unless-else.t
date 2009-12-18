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

This comment attempts to explain (and the following tests attempt to
illustrate) those cases when an {ELSE} tag inside nested {IF...} and
{UNLESS...} blocks must be explicitly qualified to disambiguate the
ELSE's beginning tag.

Tags are processed in the following order (and this order is repeated
for each loop during a call to expanded()).

IF_VAR   UNLESS_VAR
IF_INI   UNLESS_INI
IF_LOOP  UNLESS_LOOP    
IF_LVAR  UNLESS_LVAR
IF_LC    UNLESS_LC

The order of processing usually makes no difference.  But with the
{ELSE} tag (without an explicit qualifier, e.g., {ELSE_IF_LC:last}),
the order of processing can make a difference in nested IF's and
UNLESS's.

Following is an example of the regular expression used to match
the begin and end tags for {IF:VAR:varname}:

{IF_VAR:([^:}\s]+)}(.*?)(?:{ELSE(?:_IF_VAR:\1)?}(.*?))?{END_IF_VAR:\1}
--------^----------^----^-------^---------------^---------------------
        $1         $2   opt1    opt2            $3

The parens at 'opt1' show that the {ELSE} tag (and value) are
optional, and the parens at 'opt2' show that the explicit qualifier
for the {ELSE} tag is optional (unless needed, as we're discussing).

The '?' quantifiers in the parens at '$2' and '$3' show that the
values between tags are intentionally non-greedy.  Without these
quantifiers, a construct like the following wouldn't be handled well:

... {IF_VAR:a}A{END_IF_VAR:a} ... {IF_VAR:a}{VAR:a}{END_IF_VAR:a} ...

This is pertinent to this discussion, because the parens at '$2' will
locate the first {ELSE} in the data, even if it has been preceded by
another opening {IF...} or {UNLESS...} tag, e.g.,

{IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}

The values, 'B' and 'no B', imply that the {ELSE} is intended to be
interpreted as {ELSE_IF_VAR:b}, but because of the non-greedy match
in the processing of {IF_VAR:a}, the {ELSE} is instead interpreted
as {ELSE_IF_VAR:a}, i.e., you get:

A{IF_VAR:b}B

when you probably wanted:

AB

Changing the template to have an explicit ELSE as follows gives the
correct output (i.e., AB):

{IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}

The following tests will show (and exercise) those cases where the
order of processing can be anticipated so an {ELSE} tag need not be
qualified, and those cases where the order of processing requires
qualification.

If you just don't want to know any of this, it's perfectly acceptable
to qualify *all* {ELSE} tags, in which case there will never be any
ambiguities.

But if nothing else, it's good to know that you don't need anything
but "{ELSE}" if your {IF...} or {UNLESS...} block is not nested inside
another {IF...} or {UNLESS...}.

<<

#---------------------------------------------------------------------
# examples from above comments

tmpl = ... {IF_VAR:a}A{END_IF_VAR:a} ... {IF_VAR:a}{VAR:a}{END_IF_VAR:a} ...
 out = ... A ... 1 ...
 cmt = example in comment, IF_VAR:a, IF_VAR:a (non-greedy matching)

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = A{IF_VAR:b}B
 cmt = example in comment, IF_VAR:a, IF_VAR:b, ELSE is wrong

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, IF_VAR:b, ELSE is right

#---------------------------------------------------------------------
# more examples showing nested {ELSE} for same type of begin tag, e.g.
# IF_VAR...IF_VAR, UNLESS_VAR...UNLESS_VAR, etc.

# IF_VAR   UNLESS_VAR

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = A{IF_VAR:b}B
 cmt = IF_VAR:a, IF_VAR:b, ELSE is wrong

tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = IF_VAR:a, IF_VAR:b, ELSE is right

# in the following case, non-greedy matching makes non-explicit ELSE's
# ok, because the first ELSE *is* correct for the first begin tag:

tmpl = {UNLESS_VAR:a}no A{ELSE}A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{END_UNLESS_VAR:a}
 out = AB
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE is ok

# but now it's not:

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = B{END_UNLESS_VAR:b}{ELSE}A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE is wrong

# the following shows that qualifying the first ELSE makes the second
# (unqualified) ELSE match up ok ...
# (note, there's no "B" output because it's in a negative block of
# text, but now it's being parsed correctly):

tmpl = {UNLESS_VAR:a}no A{UNLESS_VAR:b}no B{ELSE_UNLESS_VAR:b}B{END_UNLESS_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, ELSE, UNLESS_VAR:b, ELSE is right

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
out = A{IF_INI:samples:b}B
cmt = IF_INI:...:a, IF_INI:...:b, ELSE is wrong

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
cmt = IF_INI:...:a, IF_INI:...:b, ELSE is right

# ELSE is ok because of correctly matched order:

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
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE is ok

# but not ok here:

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
out = B{END_UNLESS_INI:samples:b}{ELSE}A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE is wrong

# first ELSE qualified:

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
cmt = UNLESS_INI:...:a, ELSE, UNLESS_INI:...:b, ELSE is right

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
out = {LOOP:A}{LVAR:A}{IF_LOOP:B}{LVAR:B}
cmt = IF_LOOP:A, IF_LOOP:B, ELSE is wrong

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
cmt = IF_LOOP:A, IF_LOOP:B, ELSE is right

# ELSE is ok because of correctly matched order:

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
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE is ok

# but not ok here

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
out = Beta (B){END_UNLESS_LOOP:B}{ELSE}Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE is wrong

# first ELSE qualified

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
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LOOP:B, ELSE is right

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
out = Alpha{IF_LVAR:B}Beta
cmt = IF_LVAR:A, IF_LVAR:B, ELSE is wrong

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
cmt = IF_LVAR:A, IF_LVAR:B, ELSE is right

# ELSE is ok because of correctly matched order:

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
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE is ok

# but not ok here

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
out = Beta{END_UNLESS_LVAR:B}{ELSE}Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE is wrong

# first ELSE qualified

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
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LVAR:B, ELSE is right

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
out = first{IF_LC:last}last
cmt = IF_LC:first, IF_LC:last, ELSE is wrong

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
cmt = IF_LC:first, IF_LC:last, ELSE is right

# ELSE is ok because of correctly matched order:

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
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE is ok

# but not ok here:

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
out = last{END_UNLESS_LC:last}{ELSE}first
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE is wrong

# first ELSE qualified:

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
cmt = UNLESS_LC:first, ELSE, UNLESS_LC:last, ELSE is right

#---------------------------------------------------------------------
# more examples re: order of processing ...
#
#     IF_VAR   UNLESS_VAR
#     IF_INI   UNLESS_INI
#     IF_LOOP  UNLESS_LOOP    
#     IF_LVAR  UNLESS_LVAR
#     IF_LC    UNLESS_LC
#

comment = <<_end_

The above examples all showed how non-greedy matching can affect how
an ELSE tag is matched up with its beginning {IF...} or {UNLESS...}.
The examples used the same tag when nesting, e.g., IF_VAR...IF_VAR,
UNLESS_VAR...UNLESS_VAR, etc., so that the order of processing did
*not* come into play--just the non-greedy matching.

The following examples will also illustrate the effects of non-greedy
matching in exactly the same way, but will use different nested tags.
However, the first tag will always come before the second tag in the
processing order, so that the same non-greedy logic will apply, e.g.,
in the previous comment, we used this example:

{IF_VAR:a}A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{END_IF_VAR:a}

where an {IF...} tag is nested inside another {IF...} block.
Here, we'll use this example:

{IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{END_IF_VAR:a}

This example still has the same problem as the previous one:
non-greedy matching is going to associate the {ELSE} tag with
{IF_VAR:a}, not with {UNLESS_VAR:b}.  This is because {IF_VAR...}
tags are processed before {UNLESS_VAR...} tags, so we're still
dealing only with non-greedy matching.

So the same solution will fix the template: qualify the ELSE tag:

{IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE_UNLESS_VAR:b}B{END_UNLESS_VAR:b}{END_IF_VAR:a}

The examples that follow are like the examples seen so far, but
using different nested tags.  In every case the outside tag will
come before the inside tag in the processing order.

The following test is the one that started this discussion.
Rather than changing how the code is processed, I chose to
write up a bunch of test to illustrate the status quo.

Changing the regular expressions to make the order of processing
not an issue would mean very hairy expressions (they're hairy
enough already) and would possibly slow the processing down.
That's my story.

I haven't ruled it out entirely, but in the mean time, at least
these tests are here to lay it all out.

   # The following works without explicit ELSE by luck (IF_LC is processed before UNLESS_LC).
   # If this weren't the case, the first ELSE would have been linked with the UNLESS.
   # The logic is nevertheless correct, but it relies on how the code is processed, so
   #     may be the source of bugs later if we don't keep this test in place
   # In fact, this may prompt me to change how the code is processed, so everything is
   #     consistent--have to think about it.  XXX
   
   cmt  = UNLESS_LC:last with ELSE, IF_LC:break(3) with ELSE (XXX)
   tmpl = <<:chomp
   Trees: {LOOP:forest}{UNLESS_LC:last}{LVAR:tree},{IF_LC:break(3)}
   {ELSE} {END_IF_LC:break(3)}{ELSE}and {LVAR:tree}{END_UNLESS_LC:last}{END_LOOP:forest}.
   <<
   out = <<:chomp
   Trees: trident maple, southern live oak, longleaf pine,
   maidenhair tree, american beech, and american chestnut.
   <<

<<_end_

#---------------------------------------------------------------------
# examples from above comments

tmpl = {IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE}B{END_UNLESS_VAR:b}{END_IF_VAR:a}
 out = A{UNLESS_VAR:b}no B
 cmt = example in comment, IF_VAR:a, UNLESS_VAR:b, ELSE is wrong

tmpl = {IF_VAR:a}A{UNLESS_VAR:b}no B{ELSE_UNLESS_VAR:b}B{END_UNLESS_VAR:b}{END_IF_VAR:a}
 out = AB
 cmt = example in comment, IF_VAR:a, UNLESS_VAR:b, ELSE is right

#---------------------------------------------------------------------
# IF_VAR   UNLESS_VAR

# (IF_VAR comes before UNLESS_VAR)

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
out = A{UNLESS_VAR:b}no B
cmt = IF_VAR:a, UNLESS_VAR:b, ELSE is wrong

# tmpl = {IF_VAR:a}A{IF_VAR:b}B{ELSE_IF_VAR:b}no B{END_IF_VAR:b}{END_IF_VAR:a}

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
cmt = IF_VAR:a, UNLESS_VAR:b, ELSE is right

# in the following case, non-greedy matching makes non-explicit ELSE's
# ok, because the first ELSE *is* correct for the first begin tag:

# (UNLESS_VAR comes before UNLESS_INI)

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
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:...:b, ELSE is ok

# but now it's not:

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
out = B{END_UNLESS_INI:samples:b}{ELSE}A
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE is wrong

# first ELSE qualified:

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
cmt = UNLESS_VAR:a, ELSE, UNLESS_INI:samples:b, ELSE is right

#---------------------------------------------------------------------
# IF_INI   UNLESS_INI

# (IF_INI comes before UNLESS_INI)

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
out = A{UNLESS_INI:samples:b}no B
cmt = IF_INI:...:a, UNLESS_INI:...:b, ELSE is wrong

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
cmt = IF_INI:...:a, UNLESS_INI:...:b, ELSE is right

# ELSE is ok because of correctly matched order:

# (UNLESS_INI comes before UNLESS_LOOP)

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
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE is ok

# but not ok here:

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
out = B{END_UNLESS_LOOP:B}{ELSE}A
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE is wrong

# first ELSE qualified:

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
cmt = UNLESS_INI:...:a, ELSE, UNLESS_LOOP:B, ELSE is right

#---------------------------------------------------------------------
# IF_LOOP  UNLESS_LOOP    

# (IF_LOOP comes before UNLESS_LOOP)

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
out = {LOOP:A}{LVAR:A}{UNLESS_LOOP:B}no Beta
cmt = IF_LOOP:A, UNLESS_LOOP:B, ELSE is wrong

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

# ELSE is ok because of correctly matched order:

# (UNLESS_LOOP comes before UNLESS_LVAR)

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
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE is ok

# but not ok here

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
out = {LVAR:B}{END_UNLESS_LVAR:B}{ELSE}Alpha
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE is wrong

# first ELSE qualified

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
cmt = UNLESS_LOOP:A, ELSE, UNLESS_LVAR:B, ELSE is right

#---------------------------------------------------------------------
# IF_LVAR  UNLESS_LVAR

# (IF_LVAR comes before UNLESS_LVAR)

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
out = Alpha{UNLESS_LVAR:B}no Beta
cmt = IF_LVAR:A, UNLESS_LVAR:B, ELSE is wrong

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
cmt = IF_LVAR:A, UNLESS_LVAR:B, ELSE is right

# ELSE is ok because of correctly matched order:

# (UNLESS_LVAR comes before UNLESS_LC)

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
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE is ok

# but not ok here

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
out = last{END_UNLESS_LC:last}{ELSE}Alpha
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE is wrong

# first ELSE qualified

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
cmt = UNLESS_LVAR:A, ELSE, UNLESS_LC:last, ELSE is right

#---------------------------------------------------------------------
# IF_LC    UNLESS_LC

# note: first and last are both true here, because there's only one
# element in the loop ... that's helpful for these examples

# (IF_LC comes before UNLESS_LC)

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
out = first{UNLESS_LC:last}not last
cmt = IF_LC:first, UNLESS_LC:last, ELSE is wrong

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
cmt = IF_LC:first, UNLESS_LC:last, ELSE is right

#---------------------------------------------------------------------
# more examples re: order of processing ...
#
#     IF_VAR   UNLESS_VAR
#     IF_INI   UNLESS_INI
#     IF_LOOP  UNLESS_LOOP    
#     IF_LVAR  UNLESS_LVAR
#     IF_LC    UNLESS_LC
#

comment = <<_end_

The above examples all showed how non-greedy matching can affect how
an ELSE tag is matched up with its beginning {IF...} or {UNLESS...}.
The examples used the same tag when nesting, e.g., IF_VAR...IF_VAR,
UNLESS_VAR...UNLESS_VAR, etc., or they used tags in the order they
are processed, e.g., IF_VAR...UNLESS_VAR, UNLESS_LOOP...UNLESS_LVAR,
etc.  This was so that the order of processing did *not* come into
play--just the non-greedy matching.

The following examples will illustrate situations where non-greedy
matching is "trumped" by processing order, e.g., an inner nested
block is processed before it's outer block, so the inner {ELSE}
tag is simply gone by the time non-greedy matching at the outer
level comes into play.  For example,

{UNLESS_VAR:a}no A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{ELSE}A{END_UNLESS_VAR:a}

where an {IF_VAR...} tag is nested inside an {UNLESS_VAR...} block.
Based on previous examples, you might expect the {ELSE} tag to get
associated with {UNLESS_VAR:a}.  But because {IF_VAR:b} is processed
first, the {ELSE} tag is properly associated with {IF_VAR:b}, and
the processing of {UNLESS_VAR:a} never sees the {ELSE} tag.

So in this case, the {ELSE} tag does not have to be qualified.
Should it be qualified anyway?  Probably.  But in practice, it will
likely be unqualified more often, because it works and it's cleaner.
You just have to have the processing order in mind when you're making
that decision and when you're reading and maintaining the templates.

And because of this, the module will need to *retain* the same order
over time, so older templates (that have unqualified {ELSE} tags)
won't break.

The examples that follow are again like the examples seen so far, but
using different nested tags.  But now, the *inside* tag will come
before the outside tag in the processing order, illustrating more
nested situations where the {ELSE} tag does not have to be qualified.

<<_end_

#---------------------------------------------------------------------
# example from above comments

tmpl = {UNLESS_VAR:a}no A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = example in comment, UNLESS_VAR:a, IF_VAR:b, ELSE is ok

#---------------------------------------------------------------------
# more examples

# IF_VAR   UNLESS_VAR

tmpl = {UNLESS_VAR:a}no A{IF_VAR:b}B{ELSE}no B{END_IF_VAR:b}{ELSE}A{END_UNLESS_VAR:a}
 out = A
 cmt = UNLESS_VAR:a, IF_VAR:b, ELSE is ok

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
cmt = UNLESS_INI:...:a, IF_INI:...:b, ELSE is ok

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
cmt = UNLESS_LOOP:A, IF_LOOP:B, ELSE is ok

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
cmt = UNLESS_LVAR:A, IF_LVAR:B, ELSE is ok

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
cmt = UNLESS_LC:first, IF_LC:last, ELSE is ok

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

Permutations that help to prove the order:

IF_INI      IF_VAR   (check)
IF_LOOP     IF_INI   (check)
IF_LVAR     IF_LOOP  (check)
IF_LC       IF_LVAR  (check)

IF_LOOP     IF_VAR   (check)
IF_LVAR     IF_INI   (check)
IF_LC       IF_LOOP  (check)

IF_LVAR     IF_VAR   (check)
IF_LC       IF_INI   (check)

IF_LC       IF_VAR   (check)

UNLESS_INI  UNLESS_VAR   (check)
UNLESS_LOOP UNLESS_INI   (check)
UNLESS_LVAR UNLESS_LOOP  (check)
UNLESS_LC   UNLESS_LVAR  (check)

UNLESS_LOOP UNLESS_VAR   (check)
UNLESS_LVAR UNLESS_INI   (check)
UNLESS_LC   UNLESS_LOOP  (check)

UNLESS_LVAR UNLESS_VAR   (check)
UNLESS_LC   UNLESS_INI   (check)

UNLESS_LC   UNLESS_VAR   (check)

(These don't include, e.g., UNLESS_LC IF_VAR--maybe later XXX.)

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
cmt = IF_INI:...:a, IF_VAR:b, ELSE is ok

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
cmt = IF_LOOP:A, IF_INI:...:b, ELSE is ok

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
cmt = IF_LVAR:A, IF_LOOP:B, ELSE is ok

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
cmt = IF_LC:A, IF_LVAR:B, ELSE is ok

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
cmt = IF_LOOP:A, IF_VAR:b, ELSE is ok

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
cmt = IF_LVAR:A, IF_INI:samples:b, ELSE is ok

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
cmt = IF_LC:A, IF_LOOP:B, ELSE is ok

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
cmt = IF_LVAR:A, IF_VAR:b, ELSE is ok

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
cmt = IF_LC:A, IF_INI:samples:b, ELSE is ok

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
cmt = IF_LC:A, IF_VAR:b, ELSE is ok

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
cmt = UNLESS_INI:...:a, UNLESS_VAR:b, ELSE is ok

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
cmt = UNLESS_LOOP:A, UNLESS_INI:...:b, ELSE is ok

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
cmt = UNLESS_LVAR:A, UNLESS_LOOP:B, ELSE is ok

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
cmt = UNLESS_LC:A, UNLESS_LVAR:B, ELSE is ok

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
cmt = UNLESS_LOOP:A, UNLESS_VAR:b, ELSE is ok

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
cmt = UNLESS_LVAR:A, UNLESS_INI:samples:b, ELSE is ok

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
cmt = UNLESS_LC:A, UNLESS_LOOP:B, ELSE is ok

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
cmt = UNLESS_LVAR:A, UNLESS_VAR:b, ELSE is ok

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
cmt = UNLESS_LC:A, UNLESS_INI:samples:b, ELSE is ok

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
cmt = UNLESS_LC:A, UNLESS_VAR:b, ELSE is ok

#---------------------------------------------------------------------
  comment = <<_end_comment_
#---------------------------------------------------------------------

#---------------------------------------------------------------------
  <<_end_comment_
#---------------------------------------------------------------------

#---------------------------------------------------------------------

tmpl = last test
 out = last test
 cmt = last test

_end_ini_

    $ini = Config::Ini::Expanded->new( string => $ini_data );

    # calculate how many tests for Test::More
    my @tests = $ini->get( loops => 'tmpl' );
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
        forest  => $ini->get( loops => 'forest'  ),
        A       => $ini->get( loops => 'A'       ),
        B       => $ini->get( loops => 'B'       ),
    );

for ( 1 .. $num_tests ) {
    my $occ     = $_ - 1;
    my $output  = $ini->get_expanded( loops => 'tmpl', $occ );
    my $wanted  = $ini->get(          loops => 'out',  $occ );
    my $comment = $ini->get(          loops => 'cmt',  $occ );

    is( $output, $wanted, $comment );
}

__END__
