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

ini1 = Ini1
ini2 = Ini2
ini3 = Ini3

loop1 = <<:json
[
    {
        code: "code1",
        name: "name2",
        counts: [
            { type: "Search",   count: "10" },
            { type: "Browse",   count: "20" },
            { type: "Fulltext", count: "30" }
        ]
    },
    {
        code: "code2",
        name: "name2",
        counts: [
            { type: "Search",   count: "40" },
            { type: "Fulltext", count: "50" }
        ]
    },
    {
        code: "code3",
        name: "name3",
        counts: [
            { type: "Browse",   count: "60" },
            { type: "Fulltext", count: "70" }
        ]
    }
]
<<

loop2 = <<:json
[
    {
        code: "code1",
        name: "name2",
        counts: [
            { type: "Search",   count: "10" },
            { type: "Browse",   count: "20" },
            { type: "Fulltext", count: "30" }
        ]
    },
    {
        code: "code2",
        name: "name2",
        counts: [
            { type: "Search",   count: "40" },
            { type: "Fulltext", count: "50" }
        ]
    },
    {
        code: "code3",
        name: "name3",
        counts: [
            { type: "Browse",   count: "60" },
            { type: "Fulltext", count: "70" }
        ]
    }
]
<<

[tests]

cmt = IF/UNLESS_VAR VAR
tmpl = <<
1.{IF_VAR:var1}Var1:{VAR:var1}{END_IF_VAR:var1}
2.{IF_VAR:bogus}Var1:{VAR:var1}{END_IF_VAR:bogus}
3.{UNLESS_VAR:var1}Var1:{VAR:var1}{END_UNLESS_VAR:var1}
4.{UNLESS_VAR:bogus}Var1:{VAR:var1}{END_UNLESS_VAR:bogus}
<<
out = <<
1.Var1:Var1
2.
3.
4.Var1:Var1
<<

cmt = IF/UNLESS_VAR VAR ELSE
tmpl = <<
1.{IF_VAR:var1}Var1:{VAR:var1}{ELSE}No var1{END_IF_VAR:var1}
2.{IF_VAR:bogus}Var1:{VAR:var1}{ELSE}No bogus{END_IF_VAR:bogus}
3.{UNLESS_VAR:var1}No var1{ELSE}Var1:{VAR:var1}{END_UNLESS_VAR:var1}
4.{UNLESS_VAR:bogus}No bogus{ELSE}Var1:{VAR:var1}{END_UNLESS_VAR:bogus}
<<
out = <<
1.Var1:Var1
2.No bogus
3.Var1:Var1
4.No bogus
<<

cmt = IF/UNLESS_INI INI
tmpl = <<
1.{IF_INI:to_test:ini1}Ini1:{INI:to_test:ini1}{END_IF_INI:to_test:ini1}
2.{IF_INI:bogus:bogus}Ini1:{INI:to_test:ini1}{END_IF_INI:bogus:bogus}
3.{UNLESS_INI:to_test:ini1}Ini1:{INI:to_test:ini1}{END_UNLESS_INI:to_test:ini1}
4.{UNLESS_INI:bogus:bogus}Ini1:{INI:to_test:ini1}{END_UNLESS_INI:bogus:bogus}
<<
out = <<
1.Ini1:Ini1
2.
3.
4.Ini1:Ini1
<<

cmt = IF/UNLESS_INI INI ELSE
tmpl = <<
1.{IF_INI:to_test:ini1}Ini1:{INI:to_test:ini1}{ELSE}No ini1{END_IF_INI:to_test:ini1}
2.{IF_INI:bogus:bogus}Ini1:{INI:to_test:ini1}{ELSE}No bogus{END_IF_INI:bogus:bogus}
3.{UNLESS_INI:to_test:ini1}No ini1{ELSE}Ini1:{INI:to_test:ini1}{END_UNLESS_INI:to_test:ini1}
4.{UNLESS_INI:bogus:bogus}No bogus{ELSE}Ini1:{INI:to_test:ini1}{END_UNLESS_INI:bogus:bogus}
<<
out = <<
1.Ini1:Ini1
2.No bogus
3.Ini1:Ini1
4.No bogus
<<

cmt = IF/UNLESS_LOOP LOOP/LVAR
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_IF_LOOP:loop1}
2.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_IF_LOOP:bogus}
3.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
4.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:code1,code2,code3,
2.
3.
4.Loop1:code1,code2,code3,
<<

cmt = IF/UNLESS_LOOP LOOP/LVAR ELSE
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
2.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{ELSE}No bogus{END_IF_LOOP:bogus}
3.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
4.{UNLESS_LOOP:bogus}No bogus{ELSE}Loop1:{LOOP:loop1}{LVAR:code},{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:code1,code2,code3,
2.No bogus
3.Loop1:code1,code2,code3,
4.No bogus
<<

cmt = IF/UNLESS_LVAR LVAR
tmpl = <<
1.{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{END_IF_LVAR:code}{END_LOOP:loop1}
2.{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{END_IF_LVAR:bogus}{END_LOOP:loop1}
3.{LOOP:loop1}{UNLESS_LVAR:code}{LVAR:code},{END_UNLESS_LVAR:code}{END_LOOP:loop1}
4.{LOOP:loop1}{UNLESS_LVAR:bogus}{LVAR:code},{END_UNLESS_LVAR:bogus}{END_LOOP:loop1}
<<
out = <<
1.code1,code2,code3,
2.
3.
4.code1,code2,code3,
<<

cmt = IF/UNLESS_LVAR LVAR ELSE
tmpl = <<
1.{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{ELSE}No code,{END_IF_LVAR:code}{END_LOOP:loop1}
2.{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{ELSE}No bogus,{END_IF_LVAR:bogus}{END_LOOP:loop1}
3.{LOOP:loop1}{UNLESS_LVAR:code}No code,{ELSE}{LVAR:code},{END_UNLESS_LVAR:code}{END_LOOP:loop1}
4.{LOOP:loop1}{UNLESS_LVAR:bogus}No bogus,{ELSE}{LVAR:code},{END_UNLESS_LVAR:bogus}{END_LOOP:loop1}
<<
out = <<
1.code1,code2,code3,
2.No bogus,No bogus,No bogus,
3.code1,code2,code3,
4.No bogus,No bogus,No bogus,
<<

cmt = IF/UNLESS_LOOP LOOP IF/UNLESS_LVAR LVAR
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{END_IF_LVAR:code}{END_LOOP:loop1}{END_IF_LOOP:loop1}
2.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_IF_LOOP:loop1}
3.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{END_IF_LVAR:code}{END_LOOP:loop1}{END_IF_LOOP:bogus}
4.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_IF_LOOP:bogus}
5.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{END_IF_LVAR:code}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
6.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
7.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{END_IF_LVAR:code}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
8.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:code1,code2,code3,
2.Loop1:
3.
4.
5.
6.
7.Loop1:code1,code2,code3,
8.Loop1:
<<

cmt = IF/UNLESS_LOOP LOOP ELSE IF/UNLESS_LVAR LVAR ELSE
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{ELSE}No code,{END_IF_LVAR:code}{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
2.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{ELSE}No bogus,{END_IF_LVAR:bogus}{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
3.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{ELSE}No code,{END_IF_LVAR:code}{END_LOOP:loop1}{ELSE}No loop bogus{END_IF_LOOP:bogus}
4.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{ELSE}No bogus,{{END_IF_LVAR:bogus}{END_LOOP:loop1}{ELSE}No loop bogus{END_IF_LOOP:bogus}
5.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{ELSE}No code,{END_IF_LVAR:code}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
6.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{ELSE}No bogus,{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
7.{UNLESS_LOOP:bogus}No loop bogus{ELSE}Loop1:{LOOP:loop1}{IF_LVAR:code}{LVAR:code},{ELSE}No code,{END_IF_LVAR:code}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
8.{UNLESS_LOOP:bogus}No loop bogus{ELSE}Loop1:{LOOP:loop1}{IF_LVAR:bogus}{LVAR:code},{ELSE}No bogus,{END_IF_LVAR:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:code1,code2,code3,
2.Loop1:No bogus,No bogus,No bogus,
3.No loop bogus
4.No loop bogus
5.Loop1:code1,code2,code3,
6.Loop1:No bogus,No bogus,No bogus,
7.No loop bogus
8.No loop bogus
<<

#---resume

cmt = IF/UNLESS_LOOP LOOP/LC
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_IF_LOOP:loop1}
2.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_IF_LOOP:bogus}
3.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
4.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:1,,,
2.
3.
4.Loop1:1,,,
<<

cmt = IF/UNLESS_LOOP LOOP/LC ELSE
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
2.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{ELSE}No bogus{END_IF_LOOP:bogus}
3.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
4.{UNLESS_LOOP:bogus}No bogus{ELSE}Loop1:{LOOP:loop1}{LC:first},{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:1,,,
2.No bogus
3.Loop1:1,,,
4.No bogus
<<

cmt = IF/UNLESS_LC LC
tmpl = <<
1.{LOOP:loop1}{IF_LC:first}{LC:first},{END_IF_LC:first}{END_LOOP:loop1}
2.{LOOP:loop1}{IF_LC:bogus}{LC:first},{END_IF_LC:bogus}{END_LOOP:loop1}
3.{LOOP:loop1}{UNLESS_LC:first}{LC:first},{END_UNLESS_LC:first}{END_LOOP:loop1}
4.{LOOP:loop1}{UNLESS_LC:bogus}{LC:first},{END_UNLESS_LC:bogus}{END_LOOP:loop1}
<<
out = <<
1.1,
2.
3.,,
4.1,,,
<<

cmt = IF/UNLESS_LC LC ELSE
tmpl = <<
1.{LOOP:loop1}{IF_LC:first}{LC:first},{ELSE}Not first,{END_IF_LC:first}{END_LOOP:loop1}
2.{LOOP:loop1}{IF_LC:bogus}{LC:first},{ELSE}Not bogus,{END_IF_LC:bogus}{END_LOOP:loop1}
3.{LOOP:loop1}{UNLESS_LC:first}Not first,{ELSE}{LC:first},{END_UNLESS_LC:first}{END_LOOP:loop1}
4.{LOOP:loop1}{UNLESS_LC:bogus}Not bogus,{ELSE}{LC:first},{END_UNLESS_LC:bogus}{END_LOOP:loop1}
<<
out = <<
1.1,Not first,Not first,
2.Not bogus,Not bogus,Not bogus,
3.1,Not first,Not first,
4.Not bogus,Not bogus,Not bogus,
<<

cmt = IF/UNLESS_LOOP LOOP IF/UNLESS_LC LC
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{END_IF_LC:first}{END_LOOP:loop1}{END_IF_LOOP:loop1}
2.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{END_IF_LC:bogus}{END_LOOP:loop1}{END_IF_LOOP:loop1}
3.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{END_IF_LC:first}{END_LOOP:loop1}{END_IF_LOOP:bogus}
4.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{END_IF_LC:bogus}{END_LOOP:loop1}{END_IF_LOOP:bogus}
5.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{END_IF_LC:first}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
6.{UNLESS_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{END_IF_LC:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
7.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{END_IF_LC:first}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
8.{UNLESS_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{END_IF_LC:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:1,
2.Loop1:
3.
4.
5.
6.
7.Loop1:1,
8.Loop1:
<<

cmt = IF/UNLESS_LOOP LOOP ELSE IF/UNLESS_LC LC ELSE
tmpl = <<
1.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{ELSE}Not first,{END_IF_LC:first}{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
2.{IF_LOOP:loop1}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{ELSE}Not bogus,{END_IF_LC:bogus}{END_LOOP:loop1}{ELSE}No loop1{END_IF_LOOP:loop1}
3.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{ELSE}Not first,{END_IF_LC:first}{END_LOOP:loop1}{ELSE}No loop bogus{END_IF_LOOP:bogus}
4.{IF_LOOP:bogus}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{ELSE}Not bogus,{{END_IF_LC:bogus}{END_LOOP:loop1}{ELSE}No loop bogus{END_IF_LOOP:bogus}
5.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{ELSE}Not first,{END_IF_LC:first}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
6.{UNLESS_LOOP:loop1}No loop1{ELSE}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{ELSE}Not bogus,{END_IF_LC:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:loop1}
7.{UNLESS_LOOP:bogus}No loop bogus{ELSE}Loop1:{LOOP:loop1}{IF_LC:first}{LC:first},{ELSE}Not first,{END_IF_LC:first}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
8.{UNLESS_LOOP:bogus}No loop bogus{ELSE}Loop1:{LOOP:loop1}{IF_LC:bogus}{LC:first},{ELSE}Not bogus,{END_IF_LC:bogus}{END_LOOP:loop1}{END_UNLESS_LOOP:bogus}
<<
out = <<
1.Loop1:1,Not first,Not first,
2.Loop1:Not bogus,Not bogus,Not bogus,
3.No loop bogus
4.No loop bogus
5.Loop1:1,Not first,Not first,
6.Loop1:Not bogus,Not bogus,Not bogus,
7.No loop bogus
8.No loop bogus
<<

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

$ini->set_var(
    var1    => 'Var1',
    var2    => 'Var2',
    var3    => 'Var3',
    var4    => 'Var4',
);

$ini->set_loop(
    loop1 => $ini->get( to_test => 'loop1' ),
    loop2 => $ini->get( to_test => 'loop2' ),
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

x 1 VAR
x 2 IF_VAR
x 3 ELSE
x 4 UNLESS_VAR
x 5 ELSE


x 6 INI
x 7 IF_INI
x 8 ELSE
x 9 UNLESS_INI
x A ELSE


x B LOOP
x C IF_LOOP
x D ELSE
x E UNLESS_LOOP
x F ELSE


x G LVAR
x H IF_LVAR
x I ELSE
x J UNLESS_LVAR
x K ELSE


L LC:first
M IF_LC:first
N ELSE
O UNLESS_LC:first
P ELSE


Q LC:last
R IF_LC:first
S ELSE
T UNLESS_LC:first
U ELSE


V LC:inner
W IF_LC:first
X ELSE
Y UNLESS_LC:first
Z ELSE


a LC:index
b IF_LC:first
c ELSE
d UNLESS_LC:first
e ELSE


f LC:counter
g IF_LC:first
h ELSE
i UNLESS_LC:first
j ELSE


k LC:odd
l IF_LC:first
m ELSE
n UNLESS_LC:first
o ELSE


p LC:break
q IF_LC:first
r ELSE
s UNLESS_LC:first
t ELSE

