#---------------------------------------------------------------------
package Config::Ini::Expanded;

use 5.008000;
use strict;
use warnings;
use Carp;

#---------------------------------------------------------------------

=begin html

 <style type="text/css">
 @import "http://dbsdev.galib.uga.edu/sitegen/css/sitegen.css";
 body { margin: 1em; }
 </style>

=end html

=head1 NAME

Config::Ini::Expanded - Ini configuration file reading/writing with
template expansion capabilities.

=head1 SYNOPSIS

 use Config::Ini::Expanded;
 
 my $ini = Config::Ini::Expanded->new( 'file.ini' );
 
 # traverse the values
 for my $section ( $ini->get_sections() ) {
     print "$section\n";
 
     for my $name ( $ini->get_names( $section ) ) {
         print "  $name\n";
 
         for my $value ( $ini->get( $section, $name ) ) {
             print "    $value\n";
         }
     }
 }

=head1 VERSION

VERSION: 1.01

=cut

# more POD follows the __END__

#---------------------------------------------------------------------

our $VERSION = '1.01';

our @ISA = qw( Config::Ini::Edit );
use Config::Ini::Edit;
use Config::Ini::Quote ':all';
use Text::ParseWords;
use JSON;
$JSON::Pretty  = 1;
$JSON::BareKey = 1;  # *accepts* bare keys
$JSON::KeySort = 1;

our $keep_comments = 0;     # boolean, user may set to 1
our $heredoc_style = '<<';  # for as_string()
our $interpolates  = 1;     # double-quote interpolations
our $expands       = 0;     # double-quote expansions
our $include_root  = '';    # for INCLUDE/FILE expansions
our $inherits      = '';    # for inheriting from other configs
our $no_inherit    = '';    # '' means will inherit anything
our $no_override   = '';    # '' means can override anything
our $loop_limit    = 10;    # limits for detecting loops
our $size_limit    = 1_000_000;

use constant SECTIONS => 0;
use constant SHASH    => 1;
use constant ATTRS    => 2;
use constant VAR      => 3;
use constant NAMES  => 0;
use constant NHASH  => 1;
use constant SCMTS  => 2;
use constant VALS  => 0;
use constant CMTS  => 1;
use constant VATTR => 2;

# VATTR: {
#     quote     => [',"],
#     nquote    => [',"],
#     equals    => ' = ',
#     comment   => 'string',
#     herestyle => [{,{},<<,<<<<],
#     heretag   => 'string',
#     escape    => ':slash' and/or ':html',
#     indented  => indented value
#     json      => ':json',
# }
#
# object structure summary:
#           [
# SECTIONS:     [ 'section1', ],
# SHASH:        {
#                   section1 => [
#     NAMES:            [ 'name1', ],
#     NHASH:            {
#                           name1 => [
#         VALS:                 [ $value1, ],
#         CMTS:                 [ $comments, ],
#         VATTR:                [ $val_attrs, ],
#                           ],
#                       },
#     SCMTS:            [ $comments, $comment ],
#                   ],
#               },
# ATTRS:        { ... },
# VAR:          { ... },
#           ],

#---------------------------------------------------------------------
# inherited methods
## new()                                    see Config::Ini
## $ini->get_names( $section )              see Config::Ini
## $ini->add( $section, $name, @values )    see Config::Ini
## $ini->set( $section, $name, $i, $value ) see Config::Ini
## $ini->put( $section, $name, @values )    see Config::Ini
## $ini->delete_section( $section )         see Config::Ini
## $ini->delete_name( $section, $name )     see Config::Ini
## $ini->_attr( $attribute, $value )        see Config::Ini
## $ini->_autovivify( $section, $name )     see Config::Ini
## $ini->get_sections( $all )               see Config::Ini::Edit
## $ini->get_comments( $section, $name, $i )               ::Edit
## $ini->set_comments( $section, $name, $i, @comments )    ::Edit
## $ini->get_comment( $section, $name, $i )                ::Edit
## $ini->set_comment( $section, $name, $i, @comments )     ::Edit
## $ini->get_section_comments( $section )                  ::Edit
## $ini->set_section_comments( $section, @comments )       ::Edit
## $ini->get_section_comment( $section )                   ::Edit
## $ini->set_section_comment( $section, @comments )        ::Edit
## $ini->vattr( $section, $name, $i, $attribute, $value )  ::Edit

#---------------------------------------------------------------------
## $ini->init( $file )             or
## $ini->init( file   => $file   ) or
## $ini->init( fh     => $fh     ) or
## $ini->init( string => $string )
sub init {
    my ( $self, @parms ) = @_;

    my ( $file, $fh, $string, $included );
    my ( $keep, $style );
    my %parms;
    if( @parms == 1 ) { %parms = ( file => $parms[0] ) }
    else              { %parms = @parms }
    $file     = $parms{'file'};
    $fh       = $parms{'fh'};
    $string   = $parms{'string'};
    $included = $parms{'included'};

    # see AUTOLOAD() for (almost) parallel list of attributes
    for( qw(
        interpolates expands
        inherits no_inherit no_override
        include_root keep_comments heredoc_style
        loop_limit size_limit
        ) ) {
        no strict 'refs';
        $self->_attr( $_ =>
            (defined $parms{ $_ }) ? $parms{ $_ } : $$_ );
    }
    $self->_attr( file => $file ) if $file;

    my $inherits      = $self->inherits();
    my $no_override   = $self->no_override();
    my $keep_comments = $self->keep_comments();
    my $interpolates  = $self->interpolates();
    my $expands       = $self->expands();
    my $include_root  = $self->include_root();
    $self->include_root( $include_root )
        if $include_root =~ s,/+$,,;

    unless( $fh ) {
        if( $string ) {
            open $fh, '<', \$string
                or croak "Can't open string: $!"; }
        elsif( $file ) {
            open $fh, '<', $file
                or croak "Can't open $file: $!"; }
        else { croak "Invalid parms" }
    }

    my $section = '';
    my $name = '';
    my $value;
    my %vattr;
    my $comment;
    my $pending_comments = '';
    my %i;
    my $resingle = qr/' (?:  '' | [^'] )* '/x;
    my $redouble = qr/" (?: \\" | [^"] )* "/x;
    my $requoted = qr/ $resingle|$redouble /x;

    local *_;
    while( <$fh> ) {
        my $parse  = '';
        my $escape = '';
        my $json   = '';
        my $heredoc = '';
        my $q = '';

        # comment or blank line
        if( /^\s*[#;]/ or /^\s*$/ ) {
            next unless $keep_comments;
            $pending_comments .= $_;
            next;
        }

        # [section]
        if( /^\[([^\]]*)\](\s*[#;].*\s*)?/ ) {
            $section = $1;
            my $comment = $2;
            $self->_autovivify( $section );
            next unless $keep_comments;
            if( $pending_comments ) {
                $self->set_section_comments( $section, $pending_comments );
                $pending_comments = '';
            }
            $self->set_section_comment( $section, $comment ) if $comment;
            next;
        }  # if

        # <<heredoc
        # Note: name = {xyz} <<xyz>> must not be seen as a heredoc
        elsif(
            /^\s*($requoted)(\s*[=:]\s*)(<<|{)\s*([^}>]*?)\s*$/ or
            /^\s*(.+?)(\s*[=:]\s*)(<<|{)\s*([^}>]*?)\s*$/ ) {
            $name       = $1;
            $vattr{'equals'} = $2;
            my $style   = $3;
            my $heretag = $4;

            $value = '';

            my $endtag = $style eq '{' ? '}' : '<<';

            ( $q, $heretag, $comment ) = ( $1, $2, $3 )
                if $heretag =~ /^(['"])(.*)\1(\s*[#;].*)?/;
            my $indented = ($heretag =~ s/\s*:indented\s*//i ) ? 1 : '';
            my $join     = ($heretag =~ s/\s*:join\s*//i )     ? 1 : '';
            my $chomp    = ($heretag =~ s/\s*:chomp\s*//i)     ? 1 : '';
            $json   = ($heretag =~ s/\s*(:json)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:html)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:slash)\s*//i) ? $1 : '';
            $parse = $1   if $heretag =~ s/\s*:parse\s*\(\s*(.*?)\s*\)\s*//;
            $parse = '\n' if $heretag =~ s/\s*:parse\s*//;
            my $extra = '';  # strip unrecognized (future?) modifiers
            $extra .= $1 while $heretag =~ s/\s*(:\w+)\s*//;

            my $found_end;
            while( <$fh> ) {
                if( $heretag eq '' ) {
                    if( /^\s*$endtag\s*$/ ) {
                        $style .= $endtag;
                        ++$found_end;
                    }
                }
                else {
                    if( ( /^\s*\Q$heretag\E\s*$/ ||
                        /^\s*$q\Q$heretag\E$q\s*$/ ) ) {
                        ++$found_end;
                    }
                    elsif( ( /^\s*$endtag\s*\Q$heretag\E\s*$/ ||
                        /^\s*$endtag\s*$q\Q$heretag\E$q\s*$/ ) ) {
                        $style .= $endtag;
                        ++$found_end;
                    }
                }

                last         if $found_end;
                chomp $value if $join;
                if( $indented ) {
                    if( s/^(\s+)// ) {
                        $indented = $1 if $indented !~ /^\s+$/;
                    }
                }
                $value .= $_;

            }  # while

            croak "Didn't find heredoc end tag ($heretag) " .
                "for $section:$name" unless $found_end;

            # ':parse' enables ':chomp', too
            chomp $value if $chomp or $parse ne '';

            # value attributes (n/a if value parsed)
            if( $parse eq '' ) {
                $vattr{'quote'    } = $q        if $q;
                $vattr{'heretag'  } = $heretag  if $heretag;
                $vattr{'herestyle'} = $style    if $style;
                $vattr{'json'     } = $json     if $json;
                $vattr{'escape'   } = $escape   if $escape;
                $vattr{'indented' } = $indented if $indented;
                $vattr{'extra'    } = $extra    if $extra;
            }

            $heredoc = 1;

        }  # elsif (heredoc)

        # {INCLUDE:file:sections}
        elsif( /^\s*{INCLUDE:([^:{}]+)(?::([^:{}]+))*}/ ) {
            my ( $file, $sections ) = ( $1, $2 );
            croak "INCLUDE not allowed."
                if !$include_root or
                    $include_root =~ m,^/+$, or
                    $file =~ m,\.\.,;
            $file =~ s,^/+,,;
            $file = "$include_root/$file";
            next if $included->{ $file }++;
            my $ini = Config::Ini::Expanded->new(
                include_root => $include_root,
                file         => $file,
                included     => $included );
            my @sections = $sections     ?
                split(/[, ]+/,$sections) :
                $ini->get_sections();
            foreach my $section ( @sections ) {
                foreach my $name ( $ini->get_names( $section ) ) {
                    $self->add( $section, $name, 
                        $ini->get( $section, $name ) );
                }
            }
            next;
        }

        # "name" = value
        elsif( /^\s*($requoted)(\s*[=:]\s*)(.*)$/ ) {
            $name = $1;
            $vattr{'equals'} = $2;
            $value = $3;
            $vattr{'nquote'} = substr $name, 0, 1;
        }

        # name = value
        elsif( /^\s*(.+?)(\s*[=:]\s*)(.*)$/ ) {
            $name = $1;
            $vattr{'equals'} = $2;
            $value = $3;
        }

        # "bare word" (treated as boolean set to true(1))
        else {
            s/^\s+//g; s/\s+$//g;
            $name = $_;
            $value = 1;
        }

        if( $inherits and $no_override ) {
            if( $no_override->{ $section }{ $name } ) {
                # possible future feature ...
                # croak "Section:$section/Name:$name may not be overridden"
                #     if $Config::Ini::Expanded::die_on_override;
                next;
            }
        }

        my $quote = sub {
            my( $v, $q, $escape ) = @_;
            if( $q eq "'" ) { return &parse_single_quoted }
            else {
                $v = &parse_double_quoted;
                return $self->expand( $v )      if $expands;
                return $self->interpolate( $v ) if $interpolates;
                return $v; }
            };

        if( $heredoc ) {
            if( $q eq '"' ) {
                $value = parse_double_quoted( $value, '', $escape );
                if( $expands ) {
                    $value = $self->expand( $value ) }
                elsif( $interpolates ) {
                    $value = $self->interpolate( $value ) }
            }
        }
        elsif( $value =~ /^($requoted)(\s*[#;].*)?$/ ) {
            my $q = substr $1, 0, 1;
            $value = $quote->( $1, $q, $escape );
            $vattr{'quote'} = $q;
            $comment = $2 if $2 and $keep_comments;
        }

        # to allow "{INI:general:self}" = some value
        # or "A rose,\n\tby another name,\n" = smells as sweet
        if( $name =~ /^(['"]).*\1$/sm ) {
            $name = $quote->( $name, $1 );
        }

        $vattr{'comment'} = $comment if $comment;
        $comment = '';

        if( $parse ne '' ) {
            $parse = $quote->( $parse, $1 )
                if $parse =~ m,^(['"/]).*\1$,;
            $self->add( $section, $name,
                map { (defined $_) ? $_ : '' }
                parse_line( $parse, 0, $value ) );
        }
        else {
            $value = jsonToObj $value if $json;
            $self->add( $section, $name, $value );
            $self->vattr( $section, $name, $i{ $section }{ $name },
                %vattr ) if %vattr;
        }

        %vattr = ();

        if( $pending_comments ) {
            $self->set_comments( $section, $name,
                $i{ $section }{ $name }, $pending_comments );
            $pending_comments = '';
        }

        $i{ $section }{ $name }++;

    }  # while

    if( $pending_comments ) {
        $self->set_section_comments( '__END__', $pending_comments );
    }

}  # end sub init

#---------------------------------------------------------------------
## $ini->get( $section, $name, $i )
sub get {
    my ( $self, $section, $name, $i ) = @_;
    return unless defined $section;
    ( $name = $section, $section = '' ) unless defined $name;
    unless(
        exists $self->[SHASH]{ $section } and
        exists $self->[SHASH]{ $section }[NHASH]{ $name } ) {
        return unless $self->inherits();
        if( my $no_inherit = $self->no_inherit() ) {
            return if $no_inherit->{ $section }{ $name };
        }
        for my $ini ( @{$self->inherits()} ) {
            if( wantarray ) {
                my @try = $ini->get( $section, $name, $i );  # recurse
                return @try if @try;
            }
            else {
                my $try = $ini->get( $section, $name, $i );  # recurse
                return $try if defined $try;
            }
        }
        return;
    }
    my $aref = $self->[SHASH]{ $section }[NHASH]{ $name }[VALS];
    return $aref->[ $i ] if defined $i;
    return @$aref if wantarray;
    return @$aref == 1 ? $aref->[ 0 ]: "@$aref";
}

#---------------------------------------------------------------------
## $ini->get_var( $var )
sub get_var {
    my ( $self, $var ) = @_;
    unless( defined $self->[VAR] and defined $self->[VAR]{$var} ) {
        return unless $self->inherits();
        # note that no_inherit does not apply here ...
        for my $ini ( @{$self->inherits()} ) {
            my $try = $ini->get_var( $var );  # recurse
            return $try if defined $try;
        }
        return;
    }
    return $self->[VAR]{$var};
}

#---------------------------------------------------------------------
## $ini->set_var( $var, $value, ... )
sub set_var {
    my ( $self, @vars ) = @_;
    return unless @vars;
    if( @vars == 1 ) {
        if( not defined $vars[0] ) {
            delete $self->[VAR];
        }
        elsif( ref $vars[0] eq 'HASH' ) {
            my $href = $vars[0];
            $self->[VAR]{ $_ } = $href->{ $_ } for keys %$href;
        }
        else {
            croak "set_var(): Odd number of parms.";
        }
        return;
    }
    croak "set_var(): Odd number of parms." if @vars % 2;
    while( @vars ) {
        my $key = shift @vars;
        $self->[VAR]{$key} = shift @vars;
    }
}

#---------------------------------------------------------------------
## $ini->get_expanded( $section, $name, $i )
sub get_expanded {
    my ( $self, $section, $name, $i ) = @_;
    my @ret = $self->get( $section, $name, $i );
    return unless @ret;
    for( @ret ) {
        $_ = $self->expand( $_, $section, $name ) };
    return @ret if wantarray;
    return "@ret";
}

#---------------------------------------------------------------------
## $ini->expand( $value, $section, $name )
sub expand {
    my ( $self, $value, $section, $name ) = @_;
    my $changes;
    my $loops;
    while( 1 ) {  #vi{{{{{
        no warnings 'uninitialized';
        $changes += $value =~
            s/(?<!!){VAR:([^:}\s]+)}/$self->get_var($1)/ge;
        $changes += $value =~
            s/(?<!!){INI:([^:}\s]+):([^:}\s]+)(?::([^:}\s]+))?}/$self->get(
            $1,$2,$3)/ge;
        $changes += $value =~
            s/(?<!!){FILE:([^:}\s]+)}/$self->_readfile($1)/ge;
        last unless $changes;

        $changes = 0;
        if( ++$loops > $loop_limit or
            length $value > $size_limit ) {  #vi{{{{{
            my $suspect = '';
            $suspect = $1 if $value =~ /(?<!!)({VAR:[^:}\s]+}|
                {INI:[^:}\s]+:[^:}\s]+(?::[^:}\s]+)?}|
                {FILE:[^:}\s]+})/x;
            my $msg = "Loop alert at [$section], $name ($suspect):\n" .
            ((length($value) > 44) ?
            substr( $value, 0, 44 ).'...('.length($value).')...' :
            $value);
            croak $msg;
        }
    }  # while

    for( $value ) {  #vi{{{{{
        s/!({VAR:[^:}\s]+})/$1/g;
        s/!({INI:[^:}\s]+:[^:}\s]+(?::([^:}\s]+))?})/$1/g;
        s/!({FILE:[^:}\s]+})/$1/g;
    }
    return $value;
}

#---------------------------------------------------------------------
## $ini->get_interpolated( $section, $name, $i )
sub get_interpolated {
    my ( $self, $section, $name, $i ) = @_;
    my @ret = $self->get( $section, $name, $i );
    return unless @ret;
    for( @ret ) { $_ = $self->interpolate( $_ ) };
    return @ret if wantarray;
    return "@ret";
}

#---------------------------------------------------------------------
## $ini->interpolate( $value )
sub interpolate {
    my( $self, $value ) = @_;
    for ( $value ) {
        no warnings 'uninitialized';  #vi{{{{{{{{{{
        s/(?<!!){VAR:([^:}\s]+)}/$self->get_var($1)/ge;
        s/(?<!!){INI:([^:}\s]+):([^:}\s]+)(?::([^:}\s]+))?}/$self->get(
        $1,$2,$3)/ge;
        s/(?<!!){FILE:([^:}\s]+)}/$self->_readfile($1)/ge;

        s/!({VAR:[^:}\s]+})/$1/g;
        s/!({INI:[^:}\s]+:[^:}\s]+(?::([^:}\s]+))?})/$1/g;
        s/!({FILE:[^:}\s]+})/$1/g;
    }
    return $value;
}

#---------------------------------------------------------------------
## $ini->_readfile( $file )
sub _readfile {
    my ( $self, $file ) = @_;
    my $include_root = $self->include_root();
    croak "FILE not allowed."
        if !$include_root or
            $include_root =~ m,^/+$, or
            $file =~ m,\.\.,;
    $file =~ s,^/+,,;
    $file = "$include_root/$file";
    open my $fh, $file or croak "Can't open $file: $!";
    local $/;
    return <$fh>;
}

#---------------------------------------------------------------------
## AUTOLOAD() (wrapper for _attr())
## file( $filename )
## interpolates( 1 )
## expands( 1 )
## inherits( [$ini_obj1,$ini_obj2,...] )
## no_inherit(  { section1=>{name1=>1,name2=>1}, s2=>{n3=>1}, ... } )
## no_override( { section1=>{name1=>1,name2=>1}, s2=>{n3=>1}, ... } )
## include_root( $include_root )
## keep_comments( 0 )
## heredoc_style( '<<' )
## loop_limit( 10 )
## size_limit( 1_000_000 )
our $AUTOLOAD;
sub AUTOLOAD {
    my $attribute = $AUTOLOAD;
    $attribute =~ s/.*:://;

    # see init() for (almost) parallel list of attributes
    die "Undefined: $attribute()" unless $attribute =~ /^(?:
        file | interpolates | expands |
        inherits | no_inherit | no_override |
        include_root | keep_comments | heredoc_style |
        loop_limit | size_limit
        )$/x;

    my $self = shift;
    $self->_attr( $attribute, @_ );
}
sub DESTROY {}


#---------------------------------------------------------------------
1;

__END__

=head1 DESCRIPTION

This is an Ini configuration file processor.  This class inherits from
Config::Ini::Edit (and Config::Ini).  It uses those modules as well as
Config::Ini::Quote, Text::ParseWords and JSON;

=head2 Terminology

This document uses the terms I<comment>, I<section>, I<name>, and
I<value> when referring to the following parts of the Ini file syntax:

 # comment
 [section]
 name = value

In particular 'name' is the term used to refer to the named options
within the sections.  This terminology is also reflected in method
names, like C<get_sections()> and C<get_names()>.

=head2 Syntax

=head3 The I<null section>

At the top of an Ini file, before any sections have been explicitly
defined, name/value pairs may be defined.  These are assumed to be in
the 'null section', as if an explicit C<[]> line were present.

 # before any sections are defined,
 # assume section eq '', the "null section"
 name = value
 name: value

This 'null section' concept allows for very simple configuration files,
e.g.,

 title = Hello World
 color: blue
 margin: 0

=head3 Comments

Comments may begin with C<'#'> or C<';'>.

 # comments may begin with # or ;, i.e.,
 ; semicolon is valid comment character

Comments may begin on a separate line or may follow section headings.
Comments may not follow unquoted values.

 # this is a comment
 [section] # this is a comment
 name = value # this is NOT a comment (it is part of the value)

But comments may follow quoted values.

 # comments are allowed after quoted values
 name = 'value' # this is a comment
 name = "value" # this is a comment

=head3 Assignments

Spaces and tabs around the C<'='> and C<':'> assignment characters are
stripped, i.e., they are not included in the name or value.  Use
heredoc syntax to set a value with leading spaces.  Trailing spaces in
values are left intact.

 [section]
 
 # spaces/tabs around '=' are stripped
 # use heredoc to give a value with leading spaces
 # trailing spaces are left intact
 
 name=value
 name= value
 name =value
 name = value
 name    =    value
 
 # colon is valid assignment character, too.
 name:value
 name: value
 name :value
 name : value
 name    :    value

=head3 Heredocs

Heredoc syntax may be used to assign values that span multiple lines.
Heredoc syntax is supported in more ways than just the classic syntax,
as illustrated below.

 # classic heredoc:
 name = <<heredoc
 Heredocs are supported several ways.
 This is the "classic" syntax, using a
 "heredoc tag" to mark the begin and end.
 heredoc
 
 # ... and the following is supported because I kept doing this
 name = <<heredoc
 value
 <<heredoc
 
 # ... and also the following, because often no one cares what it's called
 name = <<
 value
 <<
 
 # ... and finally "block style" (for vi % support)
 name = {
 value
 }
 
 # ... and obscure variations, e.g.,
 name = {heredoc
 value
 heredoc

That is, the heredoc may begin with C<< '<<' >> or C<'{'> with or
without a tag.  And it may then end with C<< '<<' >> or C<'}'> (with or
without a tag, as it began).  When a tag is used, the ending
C<< '<<' >> or C<'}'> is optional.

=head3 Quoted Values

Values may be put in single or double quotes.

Single-quoted values will be parsed literally, except that imbedded
single quotes must be escaped by doubling them, e.g.,

 name = 'The ties that bind.'
 
 $name = $ini->get( section => 'name' );
 # $name eq "The ties that bind."

 name = 'The ''ties'' that ''bind.'''
 
 $name = $ini->get( section => 'name' );
 # $name eq "The 'ties' that 'bind.'"

This uses C<Config::Ini::Quote::parse_single_quoted()>.

Double-quoted values may be parsed a couple of different ways.  By
default, backslash-escaped unprintable characters will be unescaped to
their actual Unicode character.  This includes ascii control characters
like C<\n>, C<\t>, etc., Unicode character codes like C<\N> (Unicode
next line), C<\P> (Unicode paragraph separator), and hex-value escape
sequences like C<\x86> and C<\u263A>.

If the C<':html'> heredoc modifier is used (see Heredoc Modifiers
below), then HTML entities will be decoded (using HTML::Entities) to
their actual Unicode characters.

This uses C<Config::Ini::Quote::parse_double_quoted()>.

See Config::Ini:Quote for more details.

=head3 Heredoc :modifiers

There are several ways to modify the value in a heredoc as the Ini file
is read in (i.e., as the object is initialized):

 :chomp    - chomps the last line
 :join     - chomps every line BUT the last one
 :indented - unindents every line (strips leading whitespace)
 :parse    - splits on newline (and chomps last line)
 :parse(regex) - splits on regex (still chomps last line)
 :slash    - unescapes backslash-escaped characters in double quotes (default)
 :html     - decodes HTML entities in double quotes
 :json     - parses javascript object notation (complex data types)

The C<':parse'> modifier uses C<Text::ParseWords::parse_line()>, so
CSV-like parsing is possible.

The C<':json'> modifier uses the JSON module to parse and dump complex
data types (combinations of hashes, arrays, scalars).  The value of the
heredoc must be valid JavaScript Object Notation.

The C<':slash'> and C<':html'> modifiers are only valid when double
quotes are used (surrounding the heredoc tag and modifiers).  If no
modifiers are given with double quotes, C<':slash'> is the default.

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

 name = <<"EOT"
 \tSmiley: \u263A
 EOT

Modifiers may be stacked, e.g., C<< '<<:chomp:join:indented' >> (or
C<< '<<:chomp :join :indented' >>), in any order, but note that
C<':parse'> and C<':json'> are performed last.

 # value is "Line1\nLine2\n"
 name = <<
 Line1
 Line2
 <<
 
 # value is "Line1\nLine2"
 name = <<:chomp
 Line1
 Line2
 <<
 
 # value is "Line1Line2\n"
 name = <<:join
 Line1
 Line2
 <<
 
 # value is "Line1Line2"
 name = <<:chomp:join
 Line1
 Line2
 <<
 
 # value is "  Line1\n  Line2\n"
 name = <<
   Line1
   Line2
 <<
 
 # - indentations do NOT have to be regular to be unindented
 # - any leading spaces/tabs on every line will be stripped
 # - trailing spaces are left intact, as usual
 # value is "Line1\nLine2\n"
 name = <<:indented
   Line1
   Line2
 <<
 
 # modifiers may have spaces between them
 # value is "Line1Line2"
 name = << :chomp :join :indented
   Line1
   Line2
 <<
 
 # ... and should come after a heredoc "tag"
 # value is "Line1Line2"
 name = <<heredoc :chomp :join :indented
   Line1
   Line2
 heredoc

The C<':parse'> modifier splits a single value into multiple values.
It may be given with a regular expression parameter to split on other
than newline (the default).

 # :parse is same as :parse(\n)
 name = <<:parse
 value1
 value2
 <<

... is the same as

 name = value1
 name = value2

... and

 name = <<:parse(/,\s+/)
 "Tom, Dick, and Harry", Fred and Wilma
 <<

... is the same as

 name = Tom, Dick, and Harry
 name = Fred and Wilma

The C<':parse'> modifier chomps only the last line, so include C<'\n'>
if needed.

 # liberal separators
 name = <<:parse([,\s\n]+)
 "Tom, Dick, and Harry" "Fred and Wilma"
 Martha George, 'Hillary and Bill'
 <<

... is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma
 name = Martha
 name = George
 name = Hillary and Bill


As illustrated above, the enclosing C<'/'> characters around the
regular expression are optional.  You may also use matching quotes
instead, e.g., C<:parse('\s')>.

 name = <<:json
 { a: 1, b: 2, c: 3 }
 <<

Given the above C<':json'> example, C<< $ini->get('name') >> should
return a hashref.  Note that we accept bare hash keys
(C<$JSON::BareKey=1;>).

Modifiers must follow the heredoc characters C<< '<<' >> (or C<'{'>).
If there is a heredoc tag, e.g., C<'EOT'> below, the modifiers should
follow it, too.

 name = <<EOT:json
 { a: 1, b: 2, c: 3 }
 EOT

If you want to use single or double quotes, surround the heredoc tag
and modifiers with the appropriate quotes:

 name = <<'EOT :indented'
     line1
     line2
 EOT

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

If no heredoc tag is used, put the quotes around the modifiers.

 name = <<":html"
 vis-&agrave;-vis
 <<

If no modifiers either, just use empty quotes.

 name = <<""
 vis-\xE0-vis
 <<

Comments are allowed on the assignment line if quotes are used.

 name = <<'EOT :indented' # this is a comment
     line1
     line2
 EOT

But note:

 name = <<EOT
 'Line1' # this is NOT a comment
 EOT

=head3 Quotes in Heredocs

In heredocs, embedded single and double quotes do not have to be
(and should not be) escaped.  In other words leave single quotes as
C<"'"> (not C<"''">), and leave double quotes as C<'"'> (not C<'\"'>).

 name = <<'EOT :indented'
     'line1'
     'line2'
 EOT
 
 # $name eq "'line1'\n'line2'\n"
 $name = $ini->get( 'name' );

 name = <<"EOT :html"
 "vis-&agrave;-vis"
 EOT
 
 # $name eq qq{"vis-\xE0-vis"}
 $name = $ini->get( 'name' );

=head1 GLOBAL SETTINGS

The global settings below are stored in the object during C<init()>.
So if the global settings are subsequently changed, any existing
objects will not be affected.

=over 8

=item $Config::Ini::Expanded::keep_comments

This boolean value will determine if comments are kept when an Ini file
is loaded or when an Ini object is written out using C<as_string()>.
The default is false--comments are not kept.  The rational is this:
Unlike the Config::Ini::Edit module, the C<Expanded> module is not
indented primarily to rewrite Ini files, so it is more likely that
comments aren't needed in the object.

=item $Config::Ini::Expanded::heredoc_style

This string can be one of C<< '<<' >>, C<< '<<<<' >>, C<'{'>, or
C<'{}'> (default is C<< '<<' >>).  This determines the default heredoc
style when the object is written out using C<as_string()>.  If a value
was read in originally from a heredoc, it will be written out using
that heredoc style, not this default style.  The above values
correspond respectively to the following styles.

 # '<<'
 name = <<EOT
 Hey
 EOT

 # '<<<<'
 name = <<EOT
 Hey
 <<EOT

 # '{'
 name = {EOT
 Hey
 EOT

 # '{}'
 name = {EOT
 Hey
 }EOT

=item $Config::Ini::Expanded::interpolates

This boolean value (default: C<true>) will determine if expansion
templates in double quoted values will automatically be interpolated as
the Ini file is read in.  This includes expansion templates like
C<'{INI:section:name}'>, C<'{VAR:varname}'>, and
C<'{FILE:file_path}'>.  The C<'{INCLUDE:file_path}'> template will
always be expanded, regardless of the value of
C<$Config::Ini::Expanded::interpolates>, because it is at the section
level, not the value level.

Note that I<interpolation> is not the same as I<expansion>, such as
when C<get_expanded()> is called.  Interpolation performs a simple
one-pass replacement, while expansion performs a loop until there are
no more replacements to do.  It's like the difference between ...

 s/{(.*)}/replace($1)/ge;  # interpolation-like

and ...

 1 while s/{(.*)}/replace($1)/ge;  # expansion-like

See more about expansion templates below.

=item $Config::Ini::Expanded::expands

This boolean value (default: C<false>) will determine if expansion
templates in double quoted values will automatically be expanded as the
Ini file is read in.  This includes expansion templates like
C<'{INI:section:name}'>, C<'{VAR:varname}'>, and C<'{FILE:file_path}'>.

Note that this is different from what C<interpolates> does, because
templates will be fully expanded in a loop until there are no more
templates in the value.

See more about expansion templates below.

=item $Config::Ini::Expanded::inherits

The value of this setting will be a null string (the default) to
signify no inheritance, or an array reference pointing to an array of
Config::Ini::Expanded (or Config::Ini::Edit or Config::Ini) objects.

If such an array of objects is given, then inheritance can take place
when you call C<< $ini->get(...) >> or C<< $ini->get_var(...) >>.

That is, if your object (C<$ini>) does not have a value for the
requested parameters, Config::Ini::Expanded will travel through the
array of other objects (in the order given) until a value is found.

=item $Config::Ini::Expanded::no_inherit

The value of this setting will be a null string (the default) to
signify that anything may be inherited, or a reference to a hash of
hashes specifying section/name combinations that should not be
inherited, e.g.,

 $Config::Ini::Expanded::no_inherit = { section => { name1 => 1, name2 => 1 } };

Note the true (C<1>) values for the names.

With the above example in force, when a program calls, e.g.,
C<$ini->get( section, 'name1' );> and gets no value from the C<$ini>
object, it will B<not> inherit from any object in the C<inherits>
list.

Note that the C<no_inherit> attribute does not affect inheritance that
may take place when a program calls C<$ini->get_var()>.

=item $Config::Ini::Expanded::no_override

The value of this setting will be a null string (the default) to
signify that any inherited values may be overridden, or a reference to
a hash of hashes specifying section/name combinations that may not be
overridden, e.g.,

 $Config::Ini::Expanded::no_override = { section => { name1 => 1, name2 => 1 } };

Note the true (C<1>) values for the names.

With the above example in force, if an Ini object's C<inherits>
attribute is true, the module will not allow C<section/name1> or
C<section/name2> to be set during the C<init()> of that object.  That
is, those section/name combinations may not be overridden in an ini
file (on the assumption that they will be set in an inherited object).

=item $Config::Ini::Expanded::loop_limit

During an expansion, e.g., when you call C<get_expanded()>, a loop is
started that ends when there are no more expansions to do.  If this
loops more than the value of C<'loop_limit'>, the program will croak
with a I<Loop alert>.

The default C<'loop_limit'> is 10, which should be sufficient for most
situations.  You can increase this limit if you need to have deeper
nesting levels in your expansions.

Looping expansions allow for nested expansion templates like:

 {FILE:{INI:section:{VAR:myname}}}

The inner-most templates are expanded first.

=item $Config::Ini::Expanded::size_limit

During an expansion like described above, the value being expanded may
grow longer.  If the length of the value exceeds the value of
C<'size_limit'>, the program will croak with a I<Loop alert> (on the
assumption that the large size is the result of a loop).

The default C<'size_limit'> is 1_000_000.  Increase this limit if you
need to allow for larger values.

=item $Config::Ini::Expanded::include_root

This value is the path were C<'{INCLUDE:file_path}'> and
C<'{FILE:file_path}'> will look when file contents are read in.

 $Config::Ini::Expanded::include_root = '/web/data';
 my $ini = $Config::Ini::Expanded( string => <<'__' );
 [section]
 name = "{FILE:stuff}"
 {INCLUDE:ini/more.ini}
 __

In the above example, the value of C<< $ini->get(section=>'name') >>
would be the contents of C<'/web/data/stuff'>, and the contents of
C<'/web/data/ini/more.ini'> would be pulled in and used to augment the
Ini file contents.

=back

=head1 EXPANSION TEMPLATES

The Config::Ini::Expanded module exists in order to implement expansion
templates.  They take the following forms:

 {INCLUDE:ini_file_path}
 {INI:section:name}
 {INI:section:name:i}
 {VAR:varname}
 {FILE:file_path}

=over 8

=item {INCLUDE:ini_file_path}

The C<'{INCLUDE:ini_file_path}'> template is expanded during C<init()>
as the Ini file is read in.  This allows you to include Ini files in
other Ini files.  There is no limit to the amount of nesting allowed
other than perl's own deep recursion limits.

 [section]
 name = value
 
 {INCLUDE:second.ini}
 
 [another_section]
 name = value

The included Ini file will be loaded into the object as if its contents
existed in the main Ini file where the template appears.  It croaks if
the file cannot be opened.  It also croaks if C<< $self->include_root() >>
is not set (or is set to C<'/'>), or if C<'ini_file_path'> contains
two dots C<'..'>.

Note that this template is never expanded inside double-quoted values
or during calls to C<get_expanded()> or C<get_interpolated()>.  It is a
section-level template, not a value-level template.  See
C<'{FILE:file_path}'> below for value-level file inclusions.

=item {INI:section:name}

=item {INI:section:name:i}

The C<'{INI:section:name}'> template is expanded inside double-quoted
values and when you call C<get_expanded()> and C<get_interpolated()>.
It performs a call to C<get('section','name')> and replaces the
template with the return value.  If the value is undefined, the
template is replaced silently with a null string.

You can provide an occurrence value (array subscript), e.g.,

 name = <<""
 This is the first value: {INI:section:name:0}, and
 this is the second: {INI:section:name:1}.
 <<

=item {VAR:varname}

The C<'{VAR:varname}'> template is expanded inside double-quoted values
and when you call C<get_expanded()> and C<get_interpolated()>.  It
performs a call to C<get_var('varname')> and replaces the template
with the return value.  If the value is undefined, the template is
replaced silently with a null string.

 [letter]
 greeting = Hello {VAR:username}, today is {VAR:today}.
 ...
 
 $greeting = $ini->get_expanded( letter => 'greeting' );

=item {FILE:file_path}

The C<'{FILE:file_path}'> template is expanded inside double-quoted
values and when you call C<get_expanded()> and C<get_interpolated()>.
It replaces the template with the contents of
C<'include_root/file_path'>.  It croaks if the file cannot be opened.
It also croaks if C<< $self->include_root() >> is not set (or is set to
C<'/'>), or if C<'file_path'> contains two dots C<'..'>.

 [website]
 homepage = {FILE:homepage.html}
 ...
 
 print $ini->get_expanded( website => 'homepage' );

=item Postponed Expansion/Interpolation

Expansion and interpolation can be I<postponed> for value-level
expansion templates by placing an exclamation point (or 'bang' or 'not'
symbol) just before the opening brace of an expansion template, e.g.,

 !{INI:section:name}
 !{VAR:varname}
 !{FILE:file_path}

This feature allows you to use expansion templates to create other
expansion templates that will be expanded later (by your own program or
another program).  Depending on your needs, you may postpone multiple
times with multiple bangs, e.g.,

 !!{INI:section:name}

Each exclamation point will postpone the expansion one more time.

Note that these postponements happen inside C<expand()> and
C<interpolate()>.  Since the C<'{INCLUDE:ini_file_path}'> template is
expanded in C<init()>, it is not a value-level template and does not
have the postponement feature; its expansion cannot be postponed.

=back

=head1 METHODS

=head2 Initialization Methods

=over 8

=item new()

=item new( 'filename' )

=item new( file => 'filename' )

=item new( fh => $filehandle )

=item new( string => $string )

=item new( string => $string, file => 'filename' )

=item new( fh => $filehandle, file => 'filename' )

=item new( file => 'filename', keep_comments => 1 )

=item new( file => 'filename', heredoc_style => '{}' ), etc.

Use C<new()> to create an object, e.g.,

 my $ini = Config::Ini::Expanded->new( 'inifile' );

If you pass any parameters, the C<init()> method will be called.  If
you pass only one parameter, it's assumed to be the file name.
Otherwise, use the named parameters, C<'file'>, C<'fh'>, or C<'string'>
to pass a filename, filehandle (already open), or string.  The string
is assumed to look like the contents of an Ini file.

The parameter, C<'fh'> takes precedent over C<'string'> which takes
precedent over C<'file'>.  You may pass C<< file => 'filename' >> with
the other parameters to set the C<'file'> attribute.

Other parameters are:

C<'keep_comments'> to override the default: false.

C<'heredoc_style'> to override the default: C<< '<<' >>.
The values accepted for heredoc_style are C<< '<<' >>, C<< '<<<<' >>,
C<'{'>, or C<'{}'>.

C<'interpolates'> to override the default: 1.

C<'expands'> to override the default: 0.

C<'inherits'> to override the default: '' (no inheritance).

C<'loop_limit> to override the default: 10.

C<'size_limit'> to override the default: 1_000_000.

C<'include_root'> to override the default: '' (inclusions not
allowed).

Also see GLOBAL SETTINGS above.

If you do not pass any parameters to C<new()>, you can later call
C<init()> with the same parameters described above.

=item init( 'filename' )

=item init( file => 'filename' )

=item init( fh => $filehandle )

=item init( string => $string )

=item init( string => $string, file => 'filename' )

=item init( fh => $filehandle, file => 'filename' )

=item init( file => 'filename', keep_comments => 1 )

=item init( file => 'filename', heredoc_style => '{}' ), etc.

 my $ini = Config::Ini::Expanded->new();
 $ini->init( 'filename' );

=back

=head2 Get Methods

=over 8

=item get_sections()

Use C<get_sections()> to retrieve a list of the sections in the Ini
file.  They are returned in the order they appear in the file.

 my @sections = $ini->get_sections();

If there is a 'null section', it will be the first in the list.

If a section appears twice in a file, it only appears once in this
list.  This implies that ...

 [section1]
 name1 = value
 
 [section2]
 name2 = value
 
 [section1]
 name3 = value

is the same as ...

 [section1]
 name1 = value
 name3 = value
 
 [section2]
 name2 = value

The C<as_string()> method will output the latter.

=item get_names( $section )

Use C<get_names()> to retrieve a list of the names in a given section.

 my @names = $ini->get_names( $section );

They are returned in the order they appear in the section.

If a name appears twice in a section, it only appears once in this
list.  This implies that ...

 [section]
 name1 = value1
 name2 = value2
 name1 = another

is the same as ...

 [section]
 name1 = value1
 name1 = another
 name2 = value2

The C<as_string()> method will output the latter.

Calling C<get_names()> without a parameter is the same as calling it
with a null string: it retrieves the names from the 'null section'.
The two lines below are equivalent.

 @names = $ini->get_names();
 @names = $ini->get_names( '' );

=item get( $section, $name )

=item get( $section, $name, $i )

=item get( $name )  (assumes $section eq '')

Use C<get()> to retrieve the value or values for a given name.

Note: when an Ini object is initialized, if a name appears more than
once in a section, the values are pushed onto an array, and C<get()>
will return this array of values.

 my @values = $ini->get( $section, $name );

Pass an array subscript as the third parameter to return only one of
the values in this array.

 my $value = $ini->get( $section, $name, 0 );  # get first one
 my $value = $ini->get( $section, $name, 1 );  # get second one
 my $value = $ini->get( $section, $name, -1 ); # get last one

If the Ini file lists names at the beginning, before any sections are
given, the section name is assumed to be a null string (C<''>).  If you
call C<get()> with just one parameter, it is assumed to be a name in
this 'null section'.  If you want to pass an array subscript, then you
must also pass a null string as the first parameter.

 my @values = $ini->get( $name );         # assumes $section eq ''
 my $value  = $ini->get( '', $name, 0 );  # get first occurrence
 my $value  = $ini->get( '', $name, -1 ); # get last occurrence

If the section and name are not found, C<get()> will inherit from any
inherited objects, and if still not found will return no value.

=item get_interpolated( $section, $name )

=item get_interpolated( $section, $name, $i )

=item get_interpolated( $name )  (assumes $section eq '')

Use C<get_interpolated()> to retrieve the value or values for a given
name just as you would use C<get()> (see above).  But unlike with
C<get()>, the value will be interpolated and then returned.

 $value = $ini->get_interpolated( $section, $name );

The following expansion templates may be interpolated:

 {INI:section:name}
 {INI:section:name:i}

It expands these by calling C<get('section','name')> or
C<get('section','name',i)> and C<interpolate()>.

 {VAR:varname}

It expands this by calling C<get_var('varname')> and C<interpolate()>.
See C<get_var()> below.

 {FILE:file_path}

It expands this by reading in the contents of
C<'include_root/file_path'>.

If expansion templates are nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

only the inner-most templates will be expanded, because
C<get_interpolated()> will only do one pass through the value.

If any template resolves to an undefined value, it will be replaced
with a null string.

=item interpolate( $value )

Use C<interpolate()> to interpolate a value that may contain expansion
templates. The interpolated value is returned.  Typically you would not
call C<interpolate()>, but would instead call C<get_interpolated()>,
which itself calls C<interpolate()>.  But it is a supported method for
those times when, for example, you might want to C<get()> an
uninterpolated value and expand it later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->interpolate( $value );

=item get_expanded( $section, $name )

=item get_expanded( $section, $name, $i )

=item get_expanded( $name )  (assumes $section eq '')

Use C<get_expanded()> to retrieve the value or values for a given name
just as you would use C<get()> (see above).  But unlike with C<get()>,
the value will be expanded and then returned.

 $value = $ini->get_expanded( $section, $name );

The following expansion templates may be expanded:

 {INI:section:name}
 {INI:section:name:i}

It expands these by calling C<get('section','name')> or
C<get('section','name',i)> and C<expand()>.

 {VAR:varname}

It expands this by calling C<get_var('varname')> and C<expand()>.  See
C<get_var()> below.

 {FILE:file_path}

It expands this by reading in the contents of
C<'include_root/file_path'>.

Expansion templates may be nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

The inner-most templates are expanded first.

If any template resolves to an undefined value, it will be replaced
with a null string.

If there is a I<Loop alert> condition (e.g., the number of expansion
loops exceeds C<'loop_limit'>, or the size of the value being expanded
exceeds C<'size_limit'>), C<get_expanded()> (actually C<expand()>) will
croak.

=item expand( $value )

Use C<expand()> to expand a value that may contain expansion templates.
The expanded value is returned.  Typically you would not call
C<expand()>, but would instead call C<get_expanded()>, which itself
calls C<expand()>.  But it is a supported method for those times when,
for example, you might want to C<get()> an unexpanded value and expand
it later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->expand( $value );

If there is a I<Loop alert> condition (e.g., the number of expansion
loops exceeds C<'loop_limit'>, or the size of the value being expanded
exceeds C<'size_limit'>), C<expand()> will croak.

=back

=head2 Add/Set/Put Methods

Here, I<add> denotes pushing values onto the end, I<set>, modifying a
single value, and I<put>, replacing all values at once.

=over 8

=item add( $section, $name, @values )

Use C<add()> to add to the value or values of an option.  If the option
already has values, the new values will be added to the end (pushed
onto the array).

 $ini->add( $section, $name, @values );

To add to the 'null section', pass a null string.

 $ini->add( '', $name, @values );

=item set( $section, $name, $i, $value )

Use C<set()> to assign a single value.  Pass C<undef> to remove a value
altogether.  The C<$i> parameter is the subscript of the values array to
assign to (or remove).

 $ini->set( $section, $name, -1, $value ); # set last value
 $ini->set( $section, $name, 0, undef );   # remove first value

To set a value in the 'null section', pass a null string.

 $ini->set( '', $name, 1, $value ); # set second value

=item put( $section, $name, @values )

Use C<put()> to assign all values at once.  Any existing values are
overwritten.

 $ini->put( $section, $name, @values );

To put values in the 'null section', pass a null string.

 $ini->put( '', $name, @values );

=item set_var( 'varname', $value )

Use C<set_var()> to assign a value to a C<'varname'>.  This value will
be substituted into any expansion templates of the form,
C<'{VAR:varname}'>.

 $ini->set_var( 'today', scalar localtime );

=item get_var( $varname )

Use C<get_var()> to retrieve the value of a varname.  This method is
called by C<get_expanded()>, C<get_interpolated()>, C<expand()>, and
C<interpolate()> to expand templates of the form, C<'{VAR:varname}'>.

 $today = $ini->get_var( 'today' );

If the C<$varname> is not found, C<get_var()> will inherit from any
inherited objects, and if still not found will return no value.

=back

=head2 Delete Methods

=over 8

=item delete_section( $section )

Use C<delete_section()> to delete an entire section, including all of
its options and their values.

 $ini->delete_section( $section )

To delete the 'null section', don't pass any parameters or pass a null
string.

 $ini->delete_section();
 $ini->delete_section( '' );

=item delete_name( $section, $name )

Use C<delete_name()> to delete a named option and all of its values
from a section.

 $ini->delete_name( $section, $name );

To delete an option from the 'null section', pass just the name, or
pass a null string.

 $ini->delete_name( $name );
 $ini->delete_name( '', $name );

To delete just some of the values, you can use C<set()> with a
subscript, passing C<undef> to delete each one.  Or you can first get them
into an array using C<get()>, modify them in that array (e.g., delete
some), and then use C<put()> to replace the old values with the
modified ones.

=back

=head2 Other Accessor Methods

=over 8

=item file( $filename )

Use C<file()> to get or set the name of the object's Ini file.  Pass the
file name to set the value.  Pass C<undef> to remove the C<'file'> attribute
altogether.

 $inifile_name = $ini->file();  # get
 $ini->file( $inifile_name );   # set
 $ini->file( undef );           # remove

=item keep_comments( $boolean )

Use C<keep_comments()> to get or set the object's C<'keep_comments'>
attribute.  The default for this attribute is false, i.e., do not keep
comments.  Pass a true value to turn comments on.

 $boolean = $ini->keep_comments();  # get
 $ini->keep_comments( $boolean );   # set

C<keep_comments()> accesses the value of the flag that is stored in the
object--not the value of the global setting.

=item heredoc_style( $style )

Use C<heredoc_style()> to get or set the default style used when
heredocs are rendered by C<as_string()>.

 $style = $ini->heredoc_style();  # get
 $ini->heredoc_style( $style );   # set

The value passed should be one of C<< '<<' >>, C<< '<<<<' >>, C<'{'>,
or C<'{}'>.  The default is C<< '<<' >>.

C<heredoc_style()> accesses the value of the style that is stored in
the object--not the value of the global setting.

=item interpolates( 1 )

Use C<interpolates()> to get or set the C<'interpolates'> flag.  This
boolean value will determine if expansion templates in double quoted
values will automatically be interpolated as the Ini file is read in.
Also see C<$Config::Ini::Expanded::interpolates> for more details.

C<interpolates()> accesses the value of the flag that is stored in the
object--not the value of the global setting.

=item expands( 0 )

Use C<expands()> to get or set the C<'expands'> flag.  This boolean
value will determine if expansion templates in double quoted values
will automatically be expanded as the Ini file is read in.  Also see
C<$Config::Ini::Expanded::expands> for more details.

C<expands()> accesses the value of the flag that is stored in the
object--not the value of the global setting.

=item inherits( [$ini_obj1, $ini_obj2, ... ] )

Use C<inherits()> to get or set the C<'inherits'> attribute.  The value
should be a null string to disable inheritance, or an array reference,
like the anonymous array shown above.  This array should contain a list
of Ini objects (Config::Ini, Config::Ini::Edit, or
Config::Ini::Expanded).

It must be an array reference even if there is only one object to
inherit from, e.g.,

 $ini->inherits( [$ini_obj] );

Also see C<$Config::Ini::Expanded::inherits> for more details.

Note: B<don't> inherit from yourself.  If you do, you will get a deep
recursion error if you call C<get()> or C<get_var()> and trigger
inheritance.  Note also that inheriting from yourself can happen if you
inherit from an object that inherits from you.

C<inherits()> accesses the value of the attribute that is stored in the
object--not the value of the global setting.

=item loop_limit( 10 )

Use C<loop_limit()> to get or set the C<'loop_limit'> value.  If an
expansion loops more than the value of C<'loop_limit'>, the program
will croak with a I<Loop alert>.  Also see
C<$Config::Ini::Expanded::loop_limit> above for more details.

C<loop_limit()> accesses the limit value that is stored in the
object--not the value of the global setting.

=item size_limit( 1_000_000 )

Use C<size_limit()> to get or set the C<'size_limit'> value.  If the
length of an expanded value exceeds the value of C<'size_limit'>, the
program will croak with a I<Loop alert>.  Also see
C<$Config::Ini::Expanded::size_limit> above for more details.

C<size_limit()> accesses the limit value that is stored in the
object--not the value of the global setting.

=item include_root( $path )

Use C<include_root()> to get or set the C<'include_root'> value.  This
value is the path were C<'{INCLUDE:file_path}'> and
C<'{FILE:file_path}'> will begin looking when file contents are read
in.  Also see C<$Config::Ini::Expanded::include_root> for more
details.

When a C<'{INCLUDE:file_path}'> or C<'{FILE:file_path}'> template is
expanded, it will croak if C<'include_root'> is not set (or is set to
"/"), or if C<'file_path'> contains two dots "..".

C<include_root()> accesses the value of the path
that is stored in the object--not the value of the global
setting.

See also C<init()> and GLOBAL SETTINGS above.

=item vattr( $section, $name, $i, $attribute, $value, ... )

Use vattr() to get or set value-level attributes,
which include:

 heretag   : 'string'
 herestyle : ( {, {}, <<, or <<<< )
 quote     : ( ', ", s, d, single, or double )
 nquote    : ( ', ", s, d, single, or double )
 equals    : ( '=', ':', ' = ', ': ', etc. )
 escape    : ( :slash and/or :html )
 indented  : indentation value (white space)
 json      : boolean
 comment   : 'string'

If C<$i> is undefined, C<0> is assumed.  If there's an C<$attribute>,
but no C<$value>, the value of that attribute is returned.

 $value = $ini->vattr( $section, $name, 0, 'heretag' );  # get one

If no C<$attribute> is given, C<vattr()> returns all of the attribute
names and values as a list (in pairs).

 %attrs = $ini->vattr( $section, $name, 1 ); # get all

If C<$attribute> is a hashref, values are set from that hash.

 $ini->vattr( $section, $name, 1, { heretag=>'EOT', herestyle=>'{}' } );

Otherwise, attributes and values may be passed as named parameters.

 $ini->vattr( $section, $name, 1, heretag=>'EOT', herestyle=>'{}' );

These value attributes are used to replicate the ini file when
C<as_string()> is called.

The attributes C<'escape'>, C<'indented'>, and C<'json'> correspond to
the similarly named heredoc modifiers; see C<Heredoc Modifiers> above.
The values of C<'heretag'>, C<'herestyle'>, and C<'quote'> are used to
begin and end the heredoc.  Additionally, if double quotes are called
for, characters in the value will be escaped according to the
C<'escape'> value.

The value of C<'comment'> will be appended after the value, or if a
heredoc, after the beginning of the heredoc.  Note that the comment may
also be accessed using C<set_comment()> and C<get_comment()>.  See
Comments Accessor Methods below.

The value of C<'equals'> will be output between the name and value,
e.g., C<' = '> in C<'name = value'>.  The setting, C<'nquote'>, is to
the name what C<'quote'> is to the value, i.e., if C<"'">, the name
will be single quoted, if C<'"'>, double quoted.

Note that replicating the ":parse" heredoc modifier is not supported,
so if a file containing a ":parse" modifier is read and then rewritten
using C<as_string()>, the values will be written in their parsed form, and
may not be a heredoc any more. For example:

 [section]
 name = <<:parse
 one
 two
 <<

would be written by as_string() like this:

 [section]
 name = one
 name = two

=back

=head2 Comments Accessor Methods

An Ini file may contain comments.  Normally, when your program reads an
Ini file, it doesn't care about comments.  In Config::Ini::Expanded,
keep_comments is false by default.

Set C<$Config::Ini::Edit::keep_comments = 1;> if you go want the
Config::Ini::Edit object to retain the comments that are in the file.
The default is C<0>--comments are not kept.  This applies to C<new()>,
C<init()>, and C<as_string()>, i.e., C<new()> and C<init()> will load
the comments into the object, and C<as_string()> will output these
comments.

Or you can pass the C<'keep_comments'> parameter to the C<new()> or
C<init()> methods as described above.

=over 8

=item get_comments( $section, $name, $i )

Use C<get_comments()> to return the comments that appear B<above> a
certain name.  Since names may be repeated (forming an array of
values), pass an array index (C<$i>) to identify the comment desired.
If C<$i> is undefined, C<0> is assumed.

 my $comments = $ini->get_comments( $section, $name );

=item get_comment( $section, $name, $i )

Use C<get_comment()> (singular) to return the comments that appear
B<on> the same line as a certain name's assignment.  Pass an array
index (C<$i>) to identify the comment desired.  If C<$i> is undefined,
C<0> is assumed.

 $comment = $ini->get_comment( $section, $name );

=item set_comments( $section, $name, $i, @comments )

Use C<set_comments()> to specify comments for a given occurrence of a
name.  When C<as_string()> is called, these comments will appear
B<above> the name.

  $ini->set_comments( $section, $name, 0, 'Hello World' );

In an Ini file, comments must begin with C<'#'> or C<';'> and end with
a newline.  If your comments don't, C<'# '> and C<"\n"> will be added.

=item set_comment( $section, $name, $i, @comments )

Use C<set_comment()> to specify comments for a given occurrence of a
name.  When C<as_string()> is called, these comments will appear B<on>
the same line as the name's assignment.

  $ini->set_comment( $section, $name, 0, 'Hello World' );

In an Ini file, comments must begin with C<'#'> or C<';'>.  If your
comments don't, C<'# '> will be added.  If you pass an array of
comments, they will be strung together on one line.

=item get_section_comments( $section )

Use C<get_section_comments()> to retrieve the comments that appear B<above>
the C<[section]> line, e.g.,

 # Comment 1
 [section] # Comment 2

 # $comments eq "# Comment 1\n"
 my $comments = $ini->get_section_comments( $section );

=item get_section_comment( $section )

Use C<get_section_comment()> (note: singular 'comment') to retrieve the
comment that appears B<on> the same line as the C<[section]> line.

 # Comment 1
 [section] # Comment 2

 # $comment eq " # Comment 2\n"
 my $comment = $ini->get_section_comment( $section );

=item set_section_comments( $section, @comments )

Use C<set_section_comments()> to set the value of the comments above
the C<[section]> line.

 $ini->set_section_comments( $section, $comments );

=item set_section_comment( $section, @comments )

Use C<set_section_comment()> (singular) to set the value of the comment
at the end of the C<[section]> line.

 $ini->set_section_comment( $section, $comment );

=back

=head2 Recreating the Ini File Structure

=over 8

=item as_string()

Use C<as_string()> to dump the Config::Ini::Expanded object in an Ini
file format.  If C<$Config::Ini::Edit::keep_comments> is true, the
comments will be included.

 print INIFILE $ini->as_string();

The value C<as_string()> returns is not guaranteed to be exactly what
was in the original Ini file.  But you can expect the following:

- All sections and names will be retained.

- All values will resolve correctly, i.e., a call to C<get()> will
return the expected value.

- All comments will be present (if C<'keep_comments'> is true).

- As many value attributes as possible will be retained, e.g., quotes,
escapes, indents, etc.  But the C<':parse'> modifier will B<not> be
retained.

- If the same section appears multiple times in a file, all of its
options will be output in only one occurrence of that section, in the
position of the original first occurrence.  E.g.,

 [section1]
 name1 = value
 [section2]
 name2 = value
 [section1]
 name3 = value

will be output as

 [section1]
 name1 = value
 name3 = value
 
 [section2]
 name2 = value

(Note that as_string() inserts a blank line between sections if there
is not a comment there.)

- If the same name appears multiple times in a section, all of its
occurrences will be grouped together, at the same position as the first
occurrence.  E.g.,

 [section]
 name1 = value1
 name2 = value2
 name1 = another

will be output as

 [section]
 name1 = value1
 name1 = another
 name2 = value2

=back

=head1 SEE ALSO

Config::Ini,
Config::Ini::Edit
Config::Ini::Quote,
Config::IniFiles,
Config:: ... (many others)

=head1 AUTHOR

Brad Baxter, E<lt>bmb@mail.libs.uga.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Brad Baxter

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
