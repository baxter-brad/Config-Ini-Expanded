#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 8;

use Config::Ini::Expanded;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Expanded->new( string => $data );

$ini->set_section_comments( section1 =>
    'New Comment' );
is( $ini->get_section_comments( 'section1' ),
    "# New Comment\n",
    'set_section_comments( section, comment(no#...\n) )' );

$ini->set_section_comments( section1 =>
    '# New Comment' );
is( $ini->get_section_comments( 'section1' ),
    "# New Comment\n",
    'set_section_comments( section, comment(no...\n) )' );

$ini->set_section_comments( section1 =>
    "# New Comment\n" );
is( $ini->get_section_comments( 'section1' ),
    "# New Comment\n",
    'set_section_comments( section, comment(w/#...\n)' );

$ini->set_section_comments( section1 =>
    "abc\ndef\nghi" );
is( $ini->get_section_comments( 'section1' ),
    "# abc\n# def\n# ghi\n",
    'set_section_comments( section, comment(multiline) )' );

# set_section_comment()

$ini->set_section_comment( section1 =>
    'New Comment' );
is( $ini->get_section_comment( 'section1' ),
    " # New Comment",
    'set_section_comment( section, comment(no#...\n) )' );

$ini->set_section_comment( section1 =>
    '# New Comment' );
is( $ini->get_section_comment( 'section1' ),
    "# New Comment",
    'set_section_comment( section, comment(no...\n) )' );

$ini->set_section_comment( section1 =>
    "# New Comment" );
is( $ini->get_section_comment( 'section1' ),
    "# New Comment",
    'set_section_comment( section, comment(w/#...\n)' );

$ini->set_section_comment( section1 =>
    "abc\ndef\nghi" );
is( $ini->get_section_comment( 'section1' ),
    " # abc def ghi",
    'set_section_comment( section, comment(multiline) )' );

__DATA__
# Section 1

[section1]

# Name 1.1
name1.1 = value1.1

# Name 1.2a
name1.2 = value1.2a
# Name 1.2b
name1.2 = value1.2b

# Section 2

[section2]

# Name 2.1

name2.1 = {
value2.1
}
name2.2 = <<:chomp
value2.2
value2.2
<<
name2.3 = {here :join
value2.3
value2.3
}here
name2.4 = <<here :parse(/\n/)
value2.4
value2.4
<<here

