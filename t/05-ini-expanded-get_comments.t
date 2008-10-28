#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 1;
use Config::Ini::Expanded;

my $ini_data = do{ local $/; <DATA> };

Get_comments: {

    my $data = $ini_data;
    my $ini = Config::Ini::Expanded->new( string => $ini_data,
        keep_comments => 1 );
    my @comments = $ini->get_comments( section => 'name' );
    is( join('',@comments), "#1\n", 'get_comments ('.__LINE__.')' );
}


__DATA__
#begin
[section] #after
#1
name = 1
#2
name = 2
#3
name = 3
#end
