#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 66;
use Config::Ini::Expanded;

my $ini_data = do{ local $/; <DATA> };

Init_vs_New: {

    my $data = $ini_data;

    my $ini = Config::Ini::Expanded->new( string => $data );

    my $ini2 = Config::Ini::Expanded->new();
    $ini2->init( string => $data );

    is( $ini->as_string(), $ini2->as_string(),
        'init() vs new()' );

    local $Config::Ini::Expanded::keep_comments = 1;
    $ini = Config::Ini::Expanded->new( string => $data );
    # to get new test string if you change DATA:
    # (just make sure it's really right ...)
    # print $ini->as_string();exit;
    is(  $ini->as_string(), <<'__', 'as_string() (w/comments)' );
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
name2.3 = {here
value2.3value2.3
}here
name2.4 = value2.4
name2.4 = value2.4

__

}

Get_Methods: {

    local $Config::Ini::Expanded::keep_comments = 1;
    my $data = $ini_data;

    my $ini = Config::Ini::Expanded->new( string => $data );

    my @sections = $ini->get_sections();
    is( "@sections", 'section1 section2',
        'get_sections()' );

    my @names = map { $ini->get_names( $_ ) } @sections;
    is( "@names", 'name1.1 name1.2 name2.1 name2.2 name2.3 name2.4',
        'get_names()' );

    is( $ini->get( section1 => 'name1.1' ), 'value1.1',
        'get( section, name )' );

    is( $ini->get( section1 => 'name1.2', 1 ), 'value1.2b',
        'get( section, name, i )' );

    my @values = $ini->get( section2 => 'name2.1' );
    is( "@values", "value2.1\n",
        'get( section, name ) (heredoc)' );

    @values = $ini->get( section2 => 'name2.2' );
    is( "@values", "value2.2\nvalue2.2",
        'get( section, name ) (heredoc :chomp)' );

    @values = $ini->get( section2 => 'name2.3' );
    is( "@values", "value2.3value2.3\n",
        'get( section, name ) (heredoc :join)' );

    @values = $ini->get( section2 => 'name2.4' );
    is( "@values", "value2.4 value2.4",
        'get( section, name ) (heredoc :parse)' );

    # comments include blank lines (and newlines)

    my $comments = $ini->get_comments( section1 => 'name1.1' );
    is( $comments, "\n# Name 1.1\n",
        'get_comments( section, name )' );
        
    $comments = $ini->get_comments( section1 => 'name1.2' );
    is( $comments, "\n# Name 1.2a\n",
        'get_comments( section, name )' );
        
    $comments = $ini->get_section_comments( 'section1' );
    is( $comments, "# Section 1\n\n",
        'get_section_comments( section )' );
        
}

Put_Methods: {

    my $data = $ini_data;

    my $ini = Config::Ini::Expanded->new( string => $data );
    
    $ini->put( section1 => 'name1.1', 'abc', 'def' );
    is( join( ' ', $ini->get( section1 => 'name1.1' ) ),
        'abc def', 'put( section, name, values )' );

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

}

Add_Methods: {

    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );

    $ini->add( section3 => 'name3.1', 'value3.1' );
    is( $ini->get( section3 => 'name3.1' ), 'value3.1',
        'add( section, name, value )' );

    $ini->add( section4 => 'name4.1', 'value4.1' );
    is( $ini->get( section4 => 'name4.1' ), 'value4.1',
        'add( section(new), name, value )' );

    $ini->set_comments( section4 => 'name4.1', 0, 'Comment' );
    my @comments = $ini->get_comments( section4 => 'name4.1' );
    is( "@comments", "# Comment\n",
        'set_comments( section, name, comments(no#...\n) )' );

    $ini->set_comments( section4 => 'name4.1', 0, '# Comment' );
    my $comments = join '', $ini->get_comments( section4 => 'name4.1' );
    is( $comments, "# Comment\n",
        'set_comments( section, name, comments(no...\n) )' );

    $ini->set_comments( section4 => 'name4.1', 0, "# Comment\n" );
    $comments = join '', $ini->get_comments( section4 => 'name4.1' );
    is( $comments, "# Comment\n",
        'set_comments( section, name, comments(w/#...\n) )' );

    $ini->set_comments( section4 => 'name4.1', 0, "abc\ndef\nghi" );
    $comments = join '', $ini->get_comments( section4 => 'name4.1' );
    is( $comments, "# abc\n# def\n# ghi\n",
        'set_comments( section, name, comments(multiline) )' );

}

Delete_Methods: {

    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $data );

    $ini->delete_name( section1 => 'name1.1' );
    my @names = $ini->get_names( 'section1' );
    is( "@names", 'name1.2', 'delete_name()' );

    $ini->delete_section( 'section1' );
    my @sections = $ini->get_sections();
    is( "@sections", 'section2', 'delete_section()' );

}

Attributes: {

    my $data = $ini_data;
    my %defaults = (
        keep_comments => 0,
        heredoc_style => '<<',
        interpolates  => 1,
        expands       => 0,
        include_root  => '',
        inherits      => '',
        loop_limit    => 10,
        size_limit    => 1_000_000,
    );

    our $attr;
    for $attr ( keys %defaults ) {

        my $ini = Config::Ini::Expanded->new( string => $ini_data );
        is( $ini->_attr( $attr ), $defaults{ $attr },
            "_attr( $attr ) (default)" );

        is( $ini->_attr( $attr, 1 ), 1, "_attr( $attr, 1 ) (set)" );
        is( $ini->_attr( $attr    ), 1, "_attr( $attr ) (get)" );

        no strict 'refs';
        ${"Config::Ini::Expanded::$attr"} = 1;
        $ini = Config::Ini::Expanded->new( string => $data );

        is( $ini->_attr( $attr ), 1, "_attr( $attr ) (preset)" );
    }
}

Attributes_passed: {

    my $data = $ini_data;
    my %nondefaults = (
        keep_comments => 1,
        heredoc_style => '{',
        interpolates  => 0,
        expands       => 1,
        include_root  => '.',
        inherits      => '[]',
        loop_limit    => 9,
        size_limit    => 1_000_001,
    );

    our $attr;
    for $attr ( keys %nondefaults ) {

        my $ini = Config::Ini::Expanded->new(
            string => $ini_data,
            $attr => $nondefaults{ $attr },
            );
        is( $ini->_attr( $attr ), $nondefaults{ $attr },
            "_attr( $attr )" );
    }
}


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

