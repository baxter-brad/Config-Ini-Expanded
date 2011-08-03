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

title = Institutions/Databases Report

institutions = <<:json
[
    {
        "instname": "Institution Name",
        "instcode": "Institution Code",
        "date":     "Institution Date",
        "counts": [
            {
                "stattype": "Search",
                "commacount": "10"
            }
        ]
    }
]
<<

databases = <<:json
[
    {
        "dbsname": "Database Name",
        "dbscode": "Database Code",
        "counts": [
            {
                "stattype": "Search",
                "commacount": "10"
            }
        ]
    }
]
<<

[tests]

cmt = All names correct
tmpl = <<
{IF_INI:to_test:title}Title: {INI:to_test:title}
{END_IF_INI:to_test:title}{IF_VAR:subtitle}Subtitle: {VAR:subtitle}
{END_IF_VAR:subtitle}{LOOP:institutions}{IF_LVAR:instname}Name: {LVAR:instname}
{END_IF_LVAR:instname}Code: {LVAR:instcode}
Date: {LVAR:date}
{IF_LOOP:counts}{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{END_IF_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{END_LOOP:databases}{IF_LC:first}First:[{LC:first}]
{END_IF_LC:first}{IF_LC:last}Last:[{LC:last}]
{END_IF_LC:last}{IF_LC:inner}Inner:[{LC:inner}]
{END_IF_LC:inner}{IF_LC:odd}Odd:[{LC:odd}]
{END_IF_LC:odd}{IF_LC:index}Index:[{LC:index}]
{END_IF_LC:index}{IF_LC:counter}Counter:[{LC:counter}]{END_IF_LC:counter}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
First:[1]
Last:[1]
Odd:[1]
Counter:[1]
<<

cmt = Bad INI name
tmpl = <<
Title: {INI:to_test:title_not}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: 
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad INI section
tmpl = <<
Title: {INI:to_test_not:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: 
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad IF_INI name
tmpl = <<
{IF_INI:to_test:title_not}Title: {INI:to_test:title}
{END_IF_INI:to_test:title_not}Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad IF_INI section
tmpl = <<
{IF_INI:to_test_not:title}Title: {INI:to_test:title}
{END_IF_INI:to_test_not:title}Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad UNLESS_INI name
tmpl = <<
{UNLESS_INI:to_test:title_not}Title: {INI:to_test:title}
{END_UNLESS_INI:to_test:title_not}Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad UNLESS_INI section
tmpl = <<
{UNLESS_INI:to_test_not:title}Title: {INI:to_test:title}
{END_UNLESS_INI:to_test_not:title}Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad LOOP name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts_not}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts_not}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad IF_LOOP name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{IF_LOOP:counts_not}{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{END_IF_LOOP:counts_not}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad UNLESS_LOOP name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
Code: {LVAR:instcode}
Date: {LVAR:date}
{UNLESS_LOOP:counts_not}{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{END_UNLESS_LOOP:counts_not}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad LVAR name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname_not}
Code: {LVAR:instcode}
Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: 
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad IF_LVAR name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
{IF_LVAR:instcode_not}Code: {LVAR:instcode}
{END_IF_LVAR:instcode_not}Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
<<

cmt = Bad UNLESS_LVAR name
tmpl = <<
Title: {INI:to_test:title}
Subtitle: {VAR:subtitle}
{LOOP:institutions}Name: {LVAR:instname}
{UNLESS_LVAR:instcode_not}Code: {LVAR:instcode}
{END_UNLESS_LVAR:instcode_not}Date: {LVAR:date}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}
{END_LOOP:counts}{LOOP:databases}Name: {LVAR:dbsname}
Code: {LVAR:dbscode}
{LOOP:counts}Stattype: {LVAR:stattype}
Count: {LVAR:commacount}{END_LOOP:counts}{END_LOOP:databases}{END_LOOP:institutions}
<<
out = <<
Title: Institutions/Databases Report
Subtitle: Just testing
Name: Institution Name
Code: Institution Code
Date: Institution Date
Stattype: Search
Count: 10
Name: Database Name
Code: Database Code
Stattype: Search
Count: 10
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
    title    => $ini->get( to_test => 'title' ),
    subtitle => 'Just testing',
);

$ini->set_loop(
    institutions => $ini->get( to_test => 'institutions' ),
    databases    => $ini->get( to_test => 'databases'    ),
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
