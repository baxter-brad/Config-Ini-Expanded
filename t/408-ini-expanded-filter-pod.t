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

text = <<:json
[
{ "line": "Four score and seven years ago our fathers brought forth on this continent a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal." },
{ "line": "Now we are engaged in a great civil war, testing whether that nation, or any nation, so conceived and so dedicated, can long endure." },
{ "line": "We are met on a great battle-field of that war." },
{ "line": "We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live." },
{ "line": "It is altogether fitting and proper that we should do this." },
{ "line": "But, in a larger sense, we can not dedicate...we can not consecrate...we can not hallow this ground." },
{ "line": "The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract." },
{ "line": "The world will little note, nor long remember what we say here, but it can never forget what they did here." },
{ "line": "It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced." },
{ "line": "It is rather for us to be here dedicated to the great task remaining before us--that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion--that we here highly resolve that these dead shall not have died in vain--that this nation, under God, shall have a new birth of freedom--and that government: of the people, by the people, for the people, shall not perish from the earth." }
]
<<

address = <<
Gettysburg Address

Four score and seven years ago our fathers brought forth on this continent a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
Now we are engaged in a great civil war, testing whether that nation, or any nation, so conceived and so dedicated, can long endure.
We are met on a great battle-field of that war.
We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live.
It is altogether fitting and proper that we should do this.
But, in a larger sense, we can not dedicate...we can not consecrate...we can not hallow this ground.
The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract.
The world will little note, nor long remember what we say here, but it can never forget what they did here.
It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced.
It is rather for us to be here dedicated to the great task remaining before us--that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion--that we here highly resolve that these dead shall not have died in vain--that this nation, under God, shall have a new birth of freedom--and that government: of the people, by the people, for the people, shall not perish from the earth.
<<

[tests]

cmt = Text of Gettysburg Address
tmpl = <<:chomp
{VAR:title}

{LOOP:text}{LVAR:line}
{END_LOOP:text}
<<
out = "{INI:to_test:address}"

cmt = Text of Gettysburg Address (filtered)
tmpl = <<:chomp
<TMPL_VAR NAME="title">

<TMPL_LOOP NAME="text"><TMPL_LVAR NAME="line">
</TMPL_LOOP NAME="text">
<<
out = "{INI:to_test:address}"


#---------------------------------------------------------------------
_end_ini_

    $ini = Config::Ini::Expanded->new( string => $ini_data );

    # calculate how many tests for Test::More
    my @tests = $ini->get( tests => 'tmpl' );
    $num_tests = @tests;

}

BEGIN {  # Yup, we need another BEGIN block ...
    use Test::More tests => ( $num_tests * 2 );
}

#---------------------------------------------------------------------
# Testing ...

$ini->set_var( title => "Gettysburg Address" );

$ini->filter( sub {
    for( ${$_[0]} ) {
        s| <TMPL_VAR   \s+ NAME="(.*?)"> |{VAR:$1}|gx;
        s| <TMPL_LOOP  \s+ NAME="(.*?)"> |{LOOP:$1}|gx;
        s| <TMPL_LVAR  \s+ NAME="(.*?)"> |{LVAR:$1}|gx;
        s| </TMPL_LOOP \s+ NAME="(.*?)"> |{END_LOOP:$1}|gx;
    }
} );

$ini->set_loop(
        text  => $ini->get( to_test => 'text' ),
    );

for ( 1 .. $num_tests ) {
    my $occur   = $_ - 1;
    my $output  = $ini->get_expanded( tests => 'tmpl', $occur );
    my $wanted  = $ini->get(          tests => 'out',  $occur );
    my $comment = $ini->get(          tests => 'cmt',  $occur );

    is( $output, $wanted, $comment );
}

for ( 1 .. $num_tests ) {
    my $occur   = $_ - 1;
    my $output  = $ini->get_interpolated( tests => 'tmpl', $occur );
    my $wanted  = $ini->get(              tests => 'out',  $occur );
    my $comment = $ini->get(              tests => 'cmt',  $occur );

    is( $output, $wanted, $comment );
}

__END__
