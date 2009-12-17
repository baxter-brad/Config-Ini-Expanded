#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 8;
use File::Temp qw/ tempfile tempdir /;

BEGIN { use_ok('Config::Ini::Expanded') };
my $ini_data = do{ local $/; <DATA> };

# make a temporary ini file
my $dir = tempdir( CLEANUP => 1 );
my ( $fh, $filename ) = tempfile( DIR => $dir );
print $fh $ini_data;
close $fh;

String: {

    local $Config::Ini::Expanded::keep_comments = 1;
    my $data = $ini_data;

    my $ini = Config::Ini::Expanded->new( string => $data );
    ok( defined $ini, 'new( string )' );

    my $output = $ini->as_string();
    is( $output, $data, 'as_string() w/ comments' );

    $ini->keep_comments( 0 );
    $data =~ s/#[^\n]*\n+//;
    $data =~ s/#[^\n]*\n(?!\[)//g;
    $data =~ s/^\s*\n(?!\[)//mg;


    $output = $ini->as_string();
    is( $output, $data, 'as_string() w/o comments' );

}

File: {

    local $Config::Ini::Expanded::keep_comments = 1;

    my $ini = Config::Ini::Expanded->new( file => $filename );
    ok( defined $ini, 'new( file )' );

    my $output = $ini->as_string();
    is( $output, $ini_data, 'as_string()' );

}

FH: {

    local $Config::Ini::Expanded::keep_comments = 1;

    open my $FH, '<', $filename or die "Can't open $filename: $!";
    my $ini = Config::Ini::Expanded->new( fh => $FH );
    ok( defined $ini, 'new( fh )' );

    my $output = $ini->as_string();
    is( $output, $ini_data, 'as_string()' );

}

__DATA__
# Section 1

[section1]
name1.1 = value1.1

# Name 1.2

name1.2 = value1.2a
name1.2 = value1.2b

# Section 2

[section2]

# Name 2.1

name2.1 = {
value2.1
}

name2.1 = {:chomp
value2.1
value2.1
}
