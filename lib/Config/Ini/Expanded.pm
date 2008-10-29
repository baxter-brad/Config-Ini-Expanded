#---------------------------------------------------------------------
package Config::Ini::Expanded;

use 5.008000;
use strict;
use warnings;
use Carp;

=head1 NAME

Config::Ini::Expanded - ini-style configuration file reading/writing
with template expansion capabilities.

=head1 SYNOPSIS

 use Config::Ini::Expanded;
 
 my $ini = Config::Ini::Expanded->new( 'file.ini' );
 
 # traverse the values
 for my $section ( $ini->get_sections() ) {
     print "$section\n";
 
     for my $name ( $ini->get_names( $section ) {
         print "  $name\n";
 
         for my $value ( $ini->get( $section, $name ) ) {
             print "    $value\n";
         }
     }
 }

=head1 VERSION

VERSION = 0.10

=cut

# more POD follows the __END__

our $VERSION = '0.10';

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
our $inherits      = '';    # to inherit from other configs
our $loop_limit    = 10;
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
## $ini->get( $section, $name, $i )         see Config::Ini
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
## $ini->init( $file )            or
## $ini->init( file   =>$file   ) or
## $ini->init( fh     =>$fh     ) or
## $ini->init( string =>$string )
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

    for( qw(
        keep_comments heredoc_style interpolates
        include_root  inherits      loop_limit
        size_limit    expands
        ) ) {
        no strict 'refs';
        $self->_attr( $_ =>
            (defined $parms{ $_ }) ? $parms{ $_ } : $$_ );
    }
    $self->_attr( file => $file ) if $file;

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
        if( /^\[([^\]]+)\](\s*[#;].*\s*)?/ ) {
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
            /^\s*(.+?)(\s*[=:]\s*)(<<|{)\s*([^}>]*?)\s*$/
            ) {
            $name       = $1;
            $vattr{'equals'} = $2;
            my $style   = $3;
            my $heretag = $4;

            $value = '';

            my $endtag = $style eq '{' ? '}' : '<<';

            ( $q, $heretag, $comment ) = ( $1, $2, $3 )
                if $heretag =~ /^(['"])(.*)\1(\s*[#;].*)?$/;
            my $indented = ($heretag =~ s/\s*:indented\s*//i ) ? 1 : '';
            my $join     = ($heretag =~ s/\s*:join\s*//i )     ? 1 : '';
            my $chomp    = ($heretag =~ s/\s*:chomp\s*//i)     ? 1 : '';
            $json   = ($heretag =~ s/\s*(:json)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:html)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:slash)\s*//i) ? $1 : '';
            $parse = $1   if $heretag =~ s/\s*:parse\s*\(\s*(.*?)\s*\)\s*//;
            $parse = '\s+' if $heretag =~ s/\s*:parse\s*//;
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
        # or "A rose,\n\tby another name,\n" = smells
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
            $self->set_comments( $section, $name, $i{ $section }{ $name }, $pending_comments );
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
            length $value > $size_limit ) {
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
## keep_comments( 0 )
## heredoc_style( '<<' )
## interpolates( 1 )
## expands( 1 )
## include_root( $include_root )
## loop_limit( 10 )
## size_limit( 1_000_000 )
our $AUTOLOAD;
sub AUTOLOAD {
    my $attribute = $AUTOLOAD;
    $attribute =~ s/.*:://;
    die "Undefined: $attribute()" unless $attribute =~ /^(?:
        file | keep_comments | heredoc_style | interpolates |
        include_root | inherits | loop_limit | size_limit | expands
        )$/x;
    my $self = shift;
    $self->_attr( $attribute, @_ );
}
sub DESTROY {}


#---------------------------------------------------------------------
1;

__END__

=head1 DESCRIPTION

This is an ini-style configuration file processor.  This class
inherits from Config::Ini::Edit (and Config::Ini).  It uses
those modules as well as Config::Ini::Quote, Text::ParseWords
and JSON;

=head2 Terminology

 # comment
 [section]
 name = value

In particular 'name' is the term used to refer to the
named options within the sections.

=head2 Syntax

 # before any sections are defined,
 ; assume section eq ''--the "null section"
 name = value
 name: value

 # comments may begin with # or ;, i.e.,
 ; semicolon is valid comment character
 [section]
 # spaces/tabs around '=' are stripped
 # use heredoc to give a value with leading spaces
 # trailing spaces are left intact
 name=value
 name= value
 name =value
 name = value
 name    =    value

 # this is a comment
 [section] # this is a comment
 name = value # this is NOT a comment

 # however, comments are allowed after quoted values
 name = 'value' # this is a comment
 name = "value" # this is a comment

 # colon is valid assignment character, too.
 name:value
 name: value
 name :value
 name : value
 name    :    value

 # heredocs are supported several ways:
 
 # classic heredoc
 name = <<heredoc
 value
 heredoc

 # and because I kept doing this
 name = <<heredoc
 value
 <<heredoc

 # and because who cares what it's called
 name = <<
 value
 <<

 # and "block style" (for vi % support)
 name = {
 value
 }

 # and obscure variations, e.g.,
 name = {heredoc
 value
 heredoc

=head2 Quoted Values

Values may be put in single or double quotes.

Single-quoted values will be parsed literally,
except that imbedded single quotes must be escaped
by doubling them, e.g.,

 name = 'The ties that bind.'

 $name = $ini->get( section => 'name' );
 # $name eq "The ties that bind."

 name = 'The ''ties'' that ''bind.'''

 $name = $ini->get( section => 'name' );
 # $name eq "The 'ties' that 'bind.'"

This uses $Config::Ini::Quote::parse_single_quoted().

Double-quoted values may be parsed a couple of different
ways.  By default, backslash-escaped unprintable characters
will be unescaped to their actual Unicode character.  This
includes ascii control characters like \n, \t, etc.,
Unicode character codes like \N (Unicode next line), \P
(Unicode paragraph separator), and hex-value escape
sequences like \x86 and \u263A.

If the ':html' heredoc modifier is used (see Heredoc
Modifiers below), then HTML entities will be decoded (using
HTML::Entities) to their actual Unicode characters.

This uses $Config::Ini::Quote::parse_double_quoted(),

See also Config::Ini:Quote.

=head2 Heredoc Modifiers

There are several ways to modify the value in a heredoc as
the ini file is read in (i.e., as the object is
initialized):

 :chomp    - chomps the last line
 :join     - chomps every line BUT the last one
 :indented - unindents every line (strips leading whitespace)
 :parse    - splits on newline (chomps last line)
 :parse(regex) - splits on regex (still chomps last line)
 :slash    - unescapes backslash-escaped characters in double quotes (default)
 :html     - decodes HTML entities in double quotes
 :json     - parses javascript object notation (complex data types)

The :parse modifier uses Text::ParseWords::parse_line(),
so CSV-like parsing is possible.

The :json modifier uses the JSON module to parse and dump
complex data types (combinations of hashes, arrays, scalars).
The value of the heredoc must be valid JavaScript Object Notation.

The :slash and :html modifiers are only valid when double
quotes are used (surrounding the heredoc tag and modifiers).
If no modifiers are given with double quotes, C<:slash> is
the default.

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

 name = <<"EOT"
 \tSmiley: \u263A
 EOT

Modifiers may be stacked, e.g., <<:chomp:join:indented,
in any order (but :parse and :json are performed last).

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

 # with heredoc "tag"
 # value is "Line1Line2"
 name = <<heredoc :chomp :join :indented
   Line1
   Line2
 heredoc

The :parse modifier turns a single value into
multiple values, e.g.,

 # :parse is same as :parse(\n)
 name = <<:parse
 value1
 value2
 <<

is the same as,

 name = value1
 name = value2

and

 name = <<:parse(/,\s+/)
 "Tom, Dick, and Harry", Fred and Wilma
 <<

is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma

The :parse modifier chomps only the last line by
default, so include '\n' to parse multiple lines.

 # liberal separators
 name = <<:parse([,\s\n]+)
 "Tom, Dick, and Harry" "Fred and Wilma"
 Martha George, 'Hillary and Bill'
 <<

is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma
 name = Martha
 name = George
 name = Hillary and Bill

 name = <<:json
 { a: 1, b: 2, c: 3 }
 <<

Given the above :json example, $ini->get( 'name' )
should return a hashref.  Note that we accept bare hash keys
($JSON::BareKey = 1;).


Modifiers must follow the heredoc characters '<<' (or '{').
If there is a heredoc tag, e.g., EOT, the modifiers typically
follow it, too.

 name = <<EOT:json
 { a: 1, b: 2, c: 3 }
 EOT

If you want to use single or double quotes, surround the
heredoc tag and modifiers with the appropriate quotes:

 name = <<'EOT :indented'
     line1
     line2
 EOT

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

Note, in heredocs, embedded single and double quotes do not
have to be (and should not be) escaped.  In other words
leave single quotes as "'" (not "''"), and leave double
quotes as '"' (not '\"').

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

If no heredoc tag is used, put the quotes around
the modifiers.

 name = <<":html"
 vis-&agrave;-vis
 <<

If no modifiers, just use empty quotes.

 name = <<""
 vis-\xE0-vis
 <<

Comments are allowed on the assignment line if
quotes are used.

 name = <<'EOT :indented' # this is a comment
     line1
     line2
 EOT

But note:

 name = <<EOT
 'Line1' # this is NOT a comment
 EOT

=head1 GLOBAL SETTINGS

=over 8

Note, the global settings below are stored in the
object during init(), so if they are changed,
any existing objects will not be affected.

=item $Config::Ini::Expanded::keep_comments

This boolean value will determine if comments are kept when
an ini file is loaded during init() or when an ini object
is written out with as_string().  The default is
false--comments are not kept.  Rationalization: unlike the
Config::Ini::Edit module, the "Expanded" module is
not indented primarily to rewrite Ini files, so it is
more likely that comments aren't needed in the object.

=item $Config::Ini::Expanded::heredoc_style

This string can be one of '<<', '<<<<', '{', or '{}'
(default is '<<').  This determines the default heredoc
style when the object is written out using as_string().
Note we said, "default heredoc style."  If a value was read
in originally from a heredoc, it will be written out using
that heredoc style, not this default style.  The above
values correspond respectively to the following styles.

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

This boolean value will determine if expansion templates in
double quoted values will automatically be interpolated as the
ini file is read in.  This includes expansion templates like
C<{INI:section:name}>, C<{VAR:varname}>, and
C<{FILE:filename}>.  The C<{INCLUDE:filename}> template will
always be expanded, regardless, because it is at the section level,
not the value level.

Note that "interpolation" is not the same as "expansion",
such as when get_expanded() is called.  Interpolation
performs a simple one-pass replacement, and expansion
performs a loop until there are no more replacements to
do.  It's like the difference between:

 s/{(.*)}/replace($1)/ge;  # interpolation-like

and:

 1 while s/{(.*)}/replace($1)/ge;  # expansion-like

See more about expansion templates below.

=item $Config::Ini::Expanded::expands

This boolean value will determine if expansion templates in
double quoted values will automatically be expanded as the
ini file is read in.  This includes expansion templates like
C<{INI:section:name}>, C<{VAR:varname}>, and
C<{FILE:filename}>.

Note that this is different from what "interpolates" does,
because templates will be fully expanded in a loop until
there are no more templates in the value.

See more about expansion templates below.

=item $Config::Ini::Expanded::inherits

The value of this setting will be the null string (the
default) to signify no inheritance, or an array reference
pointing to an array of Config::Ini::Expanded (or
Config::Ini::Edit or Config::Ini) objects.  If such an
array of objects is given, and you call $ini->get(...) or
$ini->get_var(...), and if your object ($ini) does not have a
value for the requested parameters, Config::Ini::Expanded
will travel through the array of other objects (in the
order given) until a value is found.

=item $Config::Ini::Expanded::loop_limit

During an expansion, e.g., when you call get_expanded(),
a loop is started that ends when there are no more
expansions to do.  If this loops more than the value of
loop_limit, the program will croak with a "Loop alert".

The default loop_limit is 10, which should be sufficient
for most situations.  You can increase this limit if you
need to have deeper nesting levels in your expansions.

Looping expansions allow for nested expansion templates
like:

 {FILE:{INI:section:{VAR:myname}}}

The inner-most templates are expanded first.

=item $Config::Ini::Expanded::size_limit

During an expansion like described above, the value
being expanded may grow longer.  If the length of the
value exceeds the value of size_limit, the program will
croak with a "Loop alert".

The default size_limit is 1_000_000.  Increase this limit
if you need to allow for larger values.

=item $Config::Ini::Expanded::include_root

This value is the path were C<{INCLUDE:filename}> and
C<{FILE:filename}> should begin looking when file contents
are read in.  For example:

 $Config::Ini::Expanded::include_root = '/web/data';
 my $ini = $Config::Ini::Expanded( string => <<'__' );
 [section]
 name = "{FILE:stuff}"
 {INCLUDE:ini/more.ini}
 __

In the above example, the value of get->(section=>'name') would be
the contents of C</web/data/stuff>, and the contents of
C</web/data/ini/more.ini> would be pulled in and used to
augment the ini file contents.

=back

=head1 EXPANSION TEMPLATES

This module exists in order to implement
expansion templates.  They take the following
forms:

 {INCLUDE:inifilename}
 {INI:section:name[:i]}
 {VAR:varname}
 {FILE:filename}

=over 8

=item {INCLUDE:inifilename}

The C<{INCLUDE:inifilename}> template is expanded during
init() as the ini file is read in.  This allows you to
include ini files in other ini files.  There is no limit to
the amount of nesting allowed other than perl's own deep
recursion limits.

 [section]
 name = value
 
 {INCLUDE:second.ini}
 
 [another_section]
 name = value

The included ini file will be loaded into the object as if
its contents existed in the main ini file where the
template appears.  It croaks if the file cannot be opened.
It also croaks if C<$self->include_root()> is not set or is
set to "/", or if C<filename> contains two dots "..".

Note that this template is never expanded inside
double-quoted values or during calls to get_expanded() or
get_interpolated().  It is a section-level template, not a
value-level template.  See C<{FILE:filename}> below for
value-level file inclusions.

=item {INI:section:name}

=item {INI:section:name[:i]}

The C<{INI:section:name}> template is expanded inside
double-quoted values and when you call get_expanded() and
get_interpolated().  It performs a call to get( section,
name ) and replaces the template with the return value.  If
the value is undefined, the template is replaced silently
with a null string.

You can provide an occurrence value (array subscript), e.g.,

 name = <<""
 This is the first value: {INI:section:name:0}, and
 this is the second: {INI:section:name:1}.
 <<

=item {VAR:varname}

The C<{VAR:varname}> template is expanded inside
double-quoted values and when you call get_expanded() and
get_interpolated().  It performs a call to get_var( varname
) and replaces the template with the return value.  If the
value is undefined, the template is replaced silently with
a null string.

 [letter]
 greeting = Hello {VAR:username}, today is {VAR:today}.
 ...

 $greeting = $ini->get_expanded( letter => 'greeting' );


=item {FILE:filename}

The C<{FILE:filename}> template is expanded inside
double-quoted values and when you call get_expanded() and
get_interpolated().  It replaces the template with the
contents of include_root/filename.  It croaks if the file
cannot be opened.  It also croaks if C<$self->include_root()>
is not set or is set to "/", or if C<filename> contains
two dots "..".

 [website]
 homepage = {FILE:homepage.html}
 ...

 print $ini->get_expanded( website => 'homepage' );

=item Postponed Expansion/Interpolation

Expansion and interpolation can be "postponed" for
value-level expansion templates by placing an exclamation
point (or "bang" or "not" symbol) just before the opening
brace of an expansion template, e.g.,

 !{INI:section:name}
 !{VAR:varname}
 !{FILE:filename}

This feature allows you to use expansion templates to
create other expansion templates that will be expanded
later (by your own program or another program).  Depending
on your needs, you may postpone multiple times with multiple
bangs, e.g.,

 !!{INI:section:name}

Each exclamation point will postpone the expansion one more
time.

Note that these postponements happen inside expand() and
interpolate().  Since the {INCLUDE:inifilename} template is
expanded in init(), is not a value-level template, and does
not have the postponement feature, its expansion cannot be
postponed.

=back

=head1 METHODS

=head2 Initialization Methods

=over 8

=item new()

=item new( 'filename' )

=item new( file => 'filename' )

=item new( fh => $filehandle )

=item new( string => $string )

=item new( file => 'filename', keep_comments => 0 )

=item new( file => 'filename', heredoc_style => '{}' ), etc.

Use new() to create an object, e.g.,

  my $ini = Config::Ini::Expanded->new( 'inifile' );

If you pass any parameters, the init() object will be called.
If you pass only one parameter, it's assumed to be the ini file
name.  Otherwise, use the named parameters, C<file>, C<fh>,
or C<string> to pass a filename, filehandle (already open),
or string.  The string is assumed to look like the contents
of an ini file.

Other parameters are

C<keep_comments> to override the default: false.

C<heredoc_style> to override the default: '<<'.
     The values accepted for heredoc_style are
     '<<', '<<<<', '{', or '{}'.

C<interpolates> to override the default: 1.

C<expands> to override the default: 0.

C<inherits> to override the default: ''.

C<loop_limit> to override the default: 10.

C<size_limit> to override the default: 1_000_000.

C<include_root> to override the default: ''.


Also see GLOBAL SETTINGS above.

If you do not pass any parameters to new(), you can later
call init() with the same parameters described above.

=item init( 'filename' )

=item init( file => 'filename' )

=item init( fh => $filehandle )

=item init( string => $string )

=item init( file => 'filename', keep_comments => 0 )

=item init( file => 'filename', heredoc_style => '{}' ), etc.

 my $ini = Config::Ini::Expanded->new();
 $ini->init( 'filename' );

=back

=head2 Get Methods

=over 8

=item get_sections()

Use get_sections() to retrieve a list of the sections in the
ini file.  They are returned in the order they appear in the
file.

 my @sections = $ini->get_sections();

If there is a "null section", it will be the first in the
list.  If a section appears twice in a file, it only appears
once in this list.  This implies that ...

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

The method, as_string(), will output the latter.

=item get_names( $section )

Use get_names() to retrieve a list of the names in a given
section.

 my @names = $ini->get_names( $section );

They are returned in the order they appear in the
section.

If a name appears twice in a section, it only
appears once in this list.  This implies that ...

 [section]
 name1 = value1
 name2 = value2
 name1 = another

is the same as

 [section]
 name1 = value1
 name1 = another
 name2 = value2

The method, as_string(), will output the latter.

=item get( $section, $name )

=item get( $section, $name, $i )

=item get( $name )  (assumes $section eq '')

Use get() to retrieve the value(s) for a given name.
If a name appears more than once in a section, the
values are pushed onto an array, and get() will return
this array of values.

 my @values = $ini->get( $section, $name );

Pass an array subscript as the third parameter to
return only one of the values in this array.

 my $value = $ini->get( $section, $name, 0 ); # get first one
 my $value = $ini->get( $section, $name, 1 ); # get second one
 my $value = $ini->get( $section, $name, -1 ); # get last one

If the ini file lists names at the beginning, before
any sections are given, the section name is assumed to
be the null string ('').  If you call get() with just
one parameter, it is assumed to be a name in this "null
section".  If you want to pass an array subscript, then
you must also pass a null string as the first parameter.

 my @values = $ini->get( $name );         # assumes $section eq ''
 my $value  = $ini->get( '', $name, 0 );  # get first occurrence
 my $value  = $ini->get( '', $name, -1 ); # get last occurrence

This "null section" concept allows for very simple
configuration files like:

 title = Hello World
 color: blue
 margin: 0

If the section and name are not found, get() will inherit
from any inherited objects, and if still not found will
return no value.

=item get_interpolated( $section, $name )

=item get_interpolated( $section, $name, $i )

=item get_interpolated( $name )  (assumes $section eq '')

Use get_interpolated() to retrieve the value(s) for a given name
just as you would use get() (see above).  However, the value
will be interpolated and then returned.

 $value = $ini->get_interpolated( $section, $name );

The following expansion templates may be interpolated:

C<{INI:section:name}>
C<{INI:section:name:i}>
Expands by calling get( section, name or get( section, name, i ).

C<{VAR:varname}>
Expands by calling get_var( varname ).  See get_var() below.

C<{FILE:filename}>
Expands by reading in the contents of include_root/filename.

If expansion templates are nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

only the inner-most templates will be expanded, because
get_interpolated() will only do one pass through the value.

If any template resolves to an undefined value, it will
be replaced with a null string.

=item interpolate( $value )

Use interpolate() to interpolate a value that may contain
expansion templates. The interpolated value is returned.
Typically you would not call interpolate(), but would
instead call get_interpolated(), which itself calls
interpolate().  But it is a supported method for those
times when, for example, you might want to get() an
uninterpolated value and expand it later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->interpolate( $value );

=item get_expanded( $section, $name )

=item get_expanded( $section, $name, $i )

=item get_expanded( $name )  (assumes $section eq '')

Use get_expanded() to retrieve the value(s) for a given name
just as you would use get() (see above).  However, the value
will be expanded and then returned.

 $value = $ini->get_expanded( $section, $name );

The following expansion templates may be expanded:

C<{INI:section:name}>
C<{INI:section:name:i}>
Expands by calling get( section, name or get( section, name, i ).

C<{VAR:varname}>
Expands by calling get_var( varname ).  See get_var() below.

C<{FILE:filename}>
Expands by reading in the contents of include_root/filename.

Expansion templates may be nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

The inner-most templates are expanded first.

If any template resolves to an undefined value, it will
be replaced with a null string.

If there is a "Loop alert" condition (e.g., the number of
expansion loops exceeds loop_limit, or the size of the
value being expanded exceeds size_limit), get_expanded()
(actually expand()) will croak.

=item expand( $value )

Use expand() to expand a value that may contain expansion
templates. The expanded value is returned.  Typically you
would not call expand(), but would instead call
get_expanded(), which itself calls expand().  But it is a
supported method for those times when, for example, you
might want to get() an unexpanded value and expand it
later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->expand( $value );

If there is a "Loop alert" condition (e.g., the number of
expansion loops exceeds loop_limit, or the size of the
value being expanded exceeds size_limit), expand() will
croak.

=back

=head2 Add/Set/Put Methods

Here, 'add' implies pushing values onto the end,
'set', modifying a single value, and 'put', replacing
all values at once.

=over 8

=item add( $section, $name, @values )

Use add() to add to the value(s) of an option.  If
the option already has values, the new values will
be added to the end (pushed onto the array).

 $ini->add( $section, $name, @values );

To add to the "null section", pass a null string.

 $ini->add( '', $name, @values );

=item set( $section, $name, $i, $value )

Use set() to assign a single value.  Pass undef to
remove a value altogether.  The $i parameter is the
subscript of the values array to assign to (or remove).

 $ini->set( $section, $name, -1, $value ); # set last value
 $ini->set( $section, $name, 0, undef ); # remove first value

To set a value in the "null section", pass a null
string.

 $ini->set( '', $name, 1, $value ); # set second value

=item put( $section, $name, @values )

Use put() to assign all values at once.  Any
existing values are overwritten.

 $ini->put( $section, $name, @values );

To put values in the "null section", pass a null
string.

 $ini->put( '', $name, @values );

=item set_var( $varname, $value )

Use set_var() to assign a value to a "varname".  This
value will be substituted into any expansion templates
of the form, C<{VAR:varname}>.

 $ini->set_var( 'today', scalar localtime );

=item get_var( $varname )

Use get_var() to retrieve the value of a varname.  This
method is called by get_expanded(), get_interpolated(),
expand(), and interpolate() to expand templates
of the form, C<{VAR:varname}>.

 $today = $ini->get_var( 'today' );

If the $varname is not found, get_var() will inherit
from any inherited objects, and if still not found will
return no value.

=back

=head2 Delete Methods

=over 8

=item delete_section( $section )

Use delete_section() to delete an entire section,
including all of its options and their values.

 $ini->delete_section( $section )

To delete the "null section", don't
pass any parameters (or pass a null string).

 $ini->delete_section();
 $ini->delete_section( '' );

=item delete_name( $section, $name )

Use delete_name() to delete a named option and all
of its values from a section.

 $ini->delete_name( $section, $name );

To delete an option from the "null section",
pass just the name, or pass a null string.

 $ini->delete_name( $name );
 $ini->delete_name( '', $name );

To delete just some of the values, you can use set() with a
subscript, passing undef to delete that one, or you can
first get them using get(), then modify them (e.g., delete
some).  Finally, use put() to replace the old values with
the modified ones.

=back

=head2 Other Accessor Methods

=over 8

=item file( $filename )

Use file() to get or set the name of the object's
ini file.  Pass the file name to set the value.
Pass undef to remove the C<file> attribute altogether.

 $inifile_name = $ini->file();  # get
 $ini->file( $inifile_name );  # set
 $ini->file( undef );  # remove

=item keep_comments( $boolean )

Use keep_comments() to get or set the object's C<keep_comments>
attribute.  The default for this attribute is true, i.e.,
do keep comments.  Pass a false value to turn comments off.

 $boolean = $ini->keep_comments();  # get
 $ini->keep_comments( $boolean );  # set

Note that keep_comments() accesses the value of the flag
that is stored in the object--not the value of the global
setting.

=item heredoc_style( $style )

Use heredoc_style() to get or set the default style
used when heredocs are rendered by as_string().

 $style = $ini->heredoc_style();  # get
 $ini->heredoc_style( $style );  # set

The value passed should be one of '<<', '<<<<',
'{', or '{}'.  The default is '<<'.

Note that heredoc_style() accesses the value of the style
that is stored in the object--not the value of the global
setting.

=item interpolates( 1 )

Use interpolates() to get or set the interpolates flag.  This
boolean value will determine if expansion templates in
double quoted values will automatically be interpolated as
the ini file is read in.  Also see
$Config::Ini::Expanded::interpolates for more details.

Note that interpolates() accesses the value of the flag
that is stored in the object--not the value of the global
setting.

=item expands( 0 )

Use expands() to get or set the expands flag.  This
boolean value will determine if expansion templates in
double quoted values will automatically be expanded as
the ini file is read in.  Also see
$Config::Ini::Expanded::expands for more details.

Note that expands() accesses the value of the flag
that is stored in the object--not the value of the global
setting.

=item inherits( [$ini_obj1, $ini_obj2, ... ] )

Use inherits() to get or set the inherits attribute.
The value should be a null string to disable inheritance,
or an array reference (like the anonymous array shown
above).  It must be an array reference even if there
is only one object to inherit from, e.g.,

 $ini->inherits( [$ini_obj] );

Also see $Config::Ini::Expanded::inherits for more details.

Note: DON'T inherit from yourself.  If you do, you will
get a deep recursion error if you call get() or get_var()
and trigger inheritance.  Note also that inheriting from
yourself can happen if you inherit from an object that
inherits from you.

Note that inherits() accesses the value of the attribute
that is stored in the object--not the value of the global
setting.

=item loop_limit( 10 )

Use loop_limit() to get or set the limit value.  If an
expansion loops more than the value of loop_limit, the
program will croak with a "Loop alert".  Also see
$Config::Ini::Expanded::loop_limit above for more details.

Note that loop_limit() accesses the limit value that is
stored in the object--not the value of the global setting.

=item size_limit( 1_000_000 )

Use size_limit() to get or set the limit value.  If the
length of an expanded value exceeds the value of
size_limit, the program will croak with a "Loop alert".
Also see $Config::Ini::Expanded::size_limit above for
more details

Note that size_limit() accesses the limit value that is
stored in the object--not the value of the global setting.

=item include_root( $path )

Use include_root() to get or set the include_root value.
This value is the path were C<{INCLUDE:filename}> and
C<{FILE:filename}> should begin looking when file contents
are read in.  Also see $Config::Ini::Expanded::include_root
for more details.

Note that include_root() accesses the value of the path
that is stored in the object--not the value of the global
setting.  When a C<{INCLUDE:filename}> or
C<{FILE:filename}> template is expanded, it will croak if
C<$self->include_root()> is not set or is set to "/", or if
C<filename> contains two dots "..".

See also init() and GLOBAL SETTINGS above.

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

If $i is undefined, 0 is assumed.  If there's
an $attribute, but no $value, the value of that
attribute is returned.

 $value = $ini->vattr( $section, $name, 0, 'heretag' );  # get one

If no $attribute is given, vattr() returns all of the
attribute names and values as a list (in pairs).

 %attrs = $ini->vattr( $section, $name, 1 ); # get all

If $attribute is a hashref, values are set from that hash.

 $ini->vattr( $section, $name, 1, { heretag=>'EOT', herestyle=>'{}' } );

Otherwise, attributes and values may be passed as
named parameters.

 $ini->vattr( $section, $name, 1, heretag=>'EOT', herestyle=>'{}' );

These value attributes are used to replicate the ini
file when as_string() is called.

C<escape>, C<indented>, and C<json> correspond to those
heredoc modifiers; see C<Heredoc Modifiers> above.
C<heretag>, C<herestyle>, and C<quote> are used to begin
and end the heredoc.  Additionally, if double quotes are
called for, characters in the value will be escaped
according to the C<escape> modifier.

C<comment> will be appended after the value, or if a
heredoc, after the beginning of the heredoc.  Note, the
comment may also be accessed using set_comment() and
get_comment().  See Comments Accessor Methods below.

The value of C<equals> will be output between the name
and value, e.g., ' = ' between "name = value".  C<nquote>
is to the name what C<quote> is to the value, i.e., if
"'", the name will be single quoted, if '"', double.

Note that replicating the ":parse" heredoc modifier is
not supported, so if a file containing a ":parse"
modifier is read and then rewritten using as_string(),
the values will be written in their parsed form, and
may not be a heredoc any more. E.g.,

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

An ini file may contain comments.  Normally, when your
program reads an ini file, it doesn't care about comments.
In Config::Ini::Expanded, keep_comments is false by default.

Set $Config::Ini::Expanded::keep_comments to 1 if you do
want the Config::Ini::Expanded object to retain the comments
that are in the file.  The default is 0--comments are
not kept.  This applies to new(), init(), and as_string(),
i.e., if the value is 1, new() and init() will load the
comments into the object, and as_string() will output these
comments.

Or you can pass the C<keep_comments> parameter
to the new() or init() methods as described above.

=over 8

=item get_comments( $section, $name, $i )

Use get_comments() to return the comments that appear ABOVE
a certain name.  Since names may be repeated (forming an
array of values), pass an array index ($i) to identify the
comment desired.  If $i is undefined, 0 is assumed.

 my $comments = $ini->get_comments( $section, $name );

=item get_comment( $section, $name, $i )

Use get_comment() (singular) to return the comment that
appears ON the same line as a certain name's assignment.
Pass an array index ($i) to identify the comment desired.
If $i is undefined, 0 is assumed.

 $comment = $ini->get_comment( $section, $name );

=item set_comments( $section, $name, $i, @comments )

Use set_comments() to specify comments for a given
occurrence of a name.  When as_string() is called,
these comments will appear ABOVE the name.

  $ini->set_comments( $section, $name, 0, 'Hello World' );

In an ini file, comments must begin with '#' or ';' and end
with a newline.  If your comments don't, '# ' and "\n" will
be added.

=item set_comment( $section, $name, $i, @comments )

Use set_comment() to specify comments for a given
occurrence of a name.  When as_string() is called, these
comments will appear ON the same line as the name's
assignment.

  $ini->set_comment( $section, $name, 0, 'Hello World' );

In an ini file, comments must begin with '#' or ';'.  If
your comments don't, '# ' will be added.  If you pass an
array of comments, they will be strung together on one
line.

=item get_section_comments( $section )

Use get_section_comments() to retrieve the comments
that appear ABOVE the [section] line, e.g.,

 # Comment 1
 [section] # Comment 2

 my $comments = $ini->get_section_comments( $section );

In the above example, $comments eq "# Comment 1\n";

=item get_section_comment( $section )

Use get_section_comment() (note: singular 'comment') to
retrieve the comment that appears ON the same line as
the [section] line.

 # Comment 1
 [section] # Comment 2

 my $comment = $ini->get_section_comment( $section );

In the above example, $comment eq " # Comment 2\n";

=item set_section_comments( $section, @comments )

Use set_section_comments() to set the value of the
comments above the [section] line.

 $ini->set_section_comments( $section, $comments );

=item set_section_comment( $section, @comments )

Use set_section_comment() to set the value of the
comment at the end of the [section] line.

 $ini->set_section_comment( $section, $comment );

=back

=head2 Recreating the Ini File Structure

=over 8

=item as_string()

Use as_string() to dump the Config::Ini::Expanded object in an ini file
format.  If $Config::Ini::Expanded::keep_comments is true, the comments
will be included.

 print INIFILE $ini->as_string();

The value that as_string() returns is not guaranteed to be
exactly what was in the original ini file.  But you can
expect the following:

- All sections and names will be retained.

- All values will resolve correctly, i.e., a call to
get() will return the expected value.

- All comments will be present (if keep_comments is true).

- As many value attributes as possible will be retained, e.g.,
quotes, escapes, indents, etc.  But the :parse modifier will
NOT be retained.

- If the same section appears multiple times in a file,
all of its options will be output in only one occurrence
of that section, in the position of the original first
occurrence.  E.g.,

 [section1]
 name1 = value
 [section2]
 name2 = value
 [section1]
 name3 = value

will be output as,

 [section1]
 name1 = value
 name3 = value
 
 [section2]
 name2 = value

(Note that as_string() inserts a blank line between sections
if there is not a comment there.)

- If the same name appears multiple times in a section,
all of its occurrences will be grouped together, at the
same position as the first occurrence.  E.g.,

 [section]
 name1 = value1
 name2 = value2
 name1 = another

will be output as,

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

Copyright (C) 2006 by Brad Baxter

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
