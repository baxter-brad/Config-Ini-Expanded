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

sales = <<:json
[ {
    columns: [
        { name: "Bill  " },
        { name: "Martha" },
        { name: "Eva   " },
        { name: "Totals" }
        ],
    periods: [
        { name: "Jan", period_sales: [
            { name: "Red  ", color_sales: [
                { name: "Bill  ", sales: "     3" },
                { name: "Martha", sales: "    14" },
                { name: "Eva   ", sales: "    21" },
                { name: "Totals", sales: "    38" }
                ] },
            { name: "Blue ", color_sales: [
                { name: "Bill  ", sales: "     0" },
                { name: "Martha", sales: "   247" },
                { name: "Eva   ", sales: "    -3" },
                { name: "Totals", sales: "   244" }
                ] },
            { name: "Green", color_sales: [
                { name: "Bill  ", sales: "   101" },
                { name: "Martha", sales: "     0" },
                { name: "Eva   ", sales: "    10" },
                { name: "Totals", sales: "   111" }
                ] },
            { name: "Total", color_sales: [
                { name: "Bill  ", sales: "   104" },
                { name: "Martha", sales: "   261" },
                { name: "Eva   ", sales: "    28" },
                { name: "Totals", sales: "   393" }
                ] }
            ] },
        { name: "Feb", period_sales: [
            { name: "Red  ", color_sales: [
                { name: "Bill  ", sales: "    48" },
                { name: "Martha", sales: "   106" },
                { name: "Eva   ", sales: "     0" },
                { name: "Totals", sales: "   154" }
                ] },
            { name: "Blue ", color_sales: [
                { name: "Bill  ", sales: "    83" },
                { name: "Martha", sales: "     2" },
                { name: "Eva   ", sales: "     8" },
                { name: "Totals", sales: "    93" }
                ] },
            { name: "Green", color_sales: [
                { name: "Bill  ", sales: "    -4" },
                { name: "Martha", sales: "    18" },
                { name: "Eva   ", sales: "    40" },
                { name: "Totals", sales: "    54" }
                ] },
            { name: "Total", color_sales: [
                { name: "Bill  ", sales: "   127" },
                { name: "Martha", sales: "   126" },
                { name: "Eva   ", sales: "    48" },
                { name: "Totals", sales: "   201" }
                ] }
            ] },
        { name: "Mar", period_sales: [
            { name: "Red  ", color_sales: [
                { name: "Bill  ", sales: "    80" },
                { name: "Martha", sales: "    20" },
                { name: "Eva   ", sales: "     0" },
                { name: "Totals", sales: "   100" }
                ] },
            { name: "Blue ", color_sales: [
                { name: "Bill  ", sales: "    -2" },
                { name: "Martha", sales: "    18" },
                { name: "Eva   ", sales: "    20" },
                { name: "Totals", sales: "    36" }
                ] },
            { name: "Green", color_sales: [
                { name: "Bill  ", sales: "     4" },
                { name: "Martha", sales: "     8" },
                { name: "Eva   ", sales: "     6" },
                { name: "Totals", sales: "    18" }
                ] },
            { name: "Total", color_sales: [
                { name: "Bill  ", sales: "    82" },
                { name: "Martha", sales: "    46" },
                { name: "Eva   ", sales: "    26" },
                { name: "Totals", sales: "   154" }
                ] }
            ] },
        { name: "Q1 ", period_sales: [
            { name: "Red  ", color_sales: [
                { name: "Bill  ", sales: "   131" },
                { name: "Martha", sales: "   140" },
                { name: "Eva   ", sales: "    21" },
                { name: "Totals", sales: "   292" }
                ] },
            { name: "Blue ", color_sales: [
                { name: "Bill  ", sales: "    81" },
                { name: "Martha", sales: "   267" },
                { name: "Eva   ", sales: "    25" },
                { name: "Totals", sales: "   373" }
                ] },
            { name: "Green", color_sales: [
                { name: "Bill  ", sales: "   101" },
                { name: "Martha", sales: "    26" },
                { name: "Eva   ", sales: "    56" },
                { name: "Totals", sales: "   183" }
                ] },
            { name: "Total", color_sales: [
                { name: "Bill  ", sales: "   313" },
                { name: "Martha", sales: "   433" },
                { name: "Eva   ", sales: "   102" },
                { name: "Totals", sales: "   848" }
                ] }
            ] }
        ]
} ]
<<

spreadsheet = <<
Spreadsheet:
.........|Bill  |Martha|Eva   |Totals
Jan|Red  |     3|    14|    21|    38
...|Blue |     0|   247|    -3|   244
...|Green|   101|     0|    10|   111
...|Total|   104|   261|    28|   393

.........|Bill  |Martha|Eva   |Totals
Feb|Red  |    48|   106|     0|   154
...|Blue |    83|     2|     8|    93
...|Green|    -4|    18|    40|    54
...|Total|   127|   126|    48|   201

.........|Bill  |Martha|Eva   |Totals
Mar|Red  |    80|    20|     0|   100
...|Blue |    -2|    18|    20|    36
...|Green|     4|     8|     6|    18
...|Total|    82|    46|    26|   154

.........|Bill  |Martha|Eva   |Totals
Q1 |Red  |   131|   140|    21|   292
...|Blue |    81|   267|    25|   373
...|Green|   101|    26|    56|   183
...|Total|   313|   433|   102|   848
<<

[tests]

cmt  = Spreadsheet (filtered)
tmpl = <<:chomp
{LOOP:sales}Spreadsheet:
    {LOOP:periods}
        {LOOP:period_sales}
            {IF_LC:first}
.........
                {LOOP:columns}|
                    {LVAR:name}
                {END_LOOP:columns}

                {LVAR:periods:name}
            {ELSE}...
            {END_IF_LC:first}|
                {LVAR:name}
            {LOOP:color_sales}|
                {LVAR:sales}
            {END_LOOP:color_sales}

        {END_LOOP:period_sales}
    {END_LOOP:periods}
{END_LOOP:sales}
<<
out = "{INI:to_test:spreadsheet}"

cmt  = Spreadsheet (partially qualified and filtered)
tmpl = <<:chomp
{LOOP:sales}Spreadsheet:
    {LOOP:periods}
        {LOOP:period_sales}
            {IF_LC:first}
.........
                {LOOP:columns}|
                    {LVAR:name}
                {END_LOOP:columns}

                {LVAR:periods:name}
            {ELSE:first}...
            {END_IF_LC:first}|
                {LVAR:name}
            {LOOP:color_sales}|
                {LVAR:sales}
            {END_LOOP:color_sales}

        {END_LOOP:period_sales}
    {END_LOOP:periods}
{END_LOOP:sales}
<<
out = "{INI:to_test:spreadsheet}"

cmt  = Spreadsheet (qualified and filtered)
tmpl = <<:chomp
{LOOP:sales}Spreadsheet:
    {LOOP:sales:periods}
        {LOOP:periods:period_sales}
            {IF_LC:period_sales:first}
.........
                {LOOP:sales:columns}|
                    {LVAR:columns:name}
                {END_LOOP:sales:columns}

                {LVAR:periods:name}
            {ELSE_IF_LC:period_sales:first}...
            {END_IF_LC:period_sales:first}|
                {LVAR:period_sales:name}
            {LOOP:period_sales:color_sales}|
                {LVAR:color_sales:sales}
            {END_LOOP:period_sales:color_sales}

        {END_LOOP:periods:period_sales}
    {END_LOOP:sales:periods}
{END_LOOP:sales}
<<
out = "{INI:to_test:spreadsheet}"


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

$ini->filter( sub {
    for( ${$_[0]} ) {
        s| \n?[\ \t]* { LOOP       (.*?) } |{LOOP$1}|gx;
        s| \n?[\ \t]* { END_LOOP   (.*?) } |{END_LOOP$1}|gx;
        s|            { loop       (.*?) } |{LOOP$1}|gx;
        s|            { end_loop   (.*?) } |{END_LOOP$1}|gx;
        s| \n?[\ \t]* { IF         (.*?) } |{IF$1}|gx;
        s| \n?[\ \t]* { END_IF     (.*?) } |{END_IF$1}|gx;
        s|            { if         (.*?) } |{IF$1}|gx;
        s|            { end_if     (.*?) } |{END_IF$1}|gx;
        s| \n?[\ \t]* { UNLESS     (.*?) } |{UNLESS$1}|gx;
        s| \n?[\ \t]* { END_UNLESS (.*?) } |{END_UNLESS$1}|gx;
        s|            { unless     (.*?) } |{UNLESS$1}|gx;
        s|            { end_unless (.*?) } |{END_UNLESS$1}|gx;
        s| \n?[\ \t]* { ELSE       (.*?) } |{ELSE$1}|gx;
        s|            { else       (.*?) } |{ELSE$1}|gx;
        s| \n?[\ \t]* { LVAR       (.*?) } |{LVAR$1}|gx;
        s|            { lvar       (.*?) } |{LVAR$1}|gx;
        s| \n?[\ \t]* { VAR        (.*?) } |{VAR$1}|gx;
        s|            { var        (.*?) } |{VAR$1}|gx;
        s| \n?[\ \t]* { INI        (.*?) } |{INI$1}|gx;
        s|            { ini        (.*?) } |{INI$1}|gx;
    }
} );

$ini->set_loop(
        sales  => $ini->get( to_test => 'sales' ),
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
