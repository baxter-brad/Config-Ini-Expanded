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

VERSION: 1.17

=head1 See Config::Ini::Expanded::POD.

All of the POD for this module may be found in Config::Ini::Expanded::POD.

=cut

#---------------------------------------------------------------------
# http://www.dagolden.com/index.php/369/version-numbers-should-be-boring/

our $VERSION = '1.17';
$VERSION = eval $VERSION;

our @ISA = qw( Config::Ini::Edit );
use Config::Ini::Edit;
use Config::Ini::Quote ':all';
use Text::ParseWords;
use JSON;

our $encoding      = '';    # for new()/init(), {FILE:...}
our $keep_comments = 0;     # boolean, user may set to 1
our $heredoc_style = '<<';  # for as_string()
our $interpolates  = 1;     # double-quote interpolations
our $expands       = 0;     # double-quote expansions
our $include_root  = '';    # for INCLUDE/FILE expansions
our $inherits      = '';    # for inheriting from other configs
our $no_inherit    = '';    # '' means will inherit anything
our $no_override   = '';    # '' means can override anything
our $filter;                # for template placeholders
our $callbacks;             # for escape_html(), etc.
our $loop_limit    = 10;    # limits for detecting loops
our $size_limit    = 1_000_000;

my $Var_rx = qr/[^:}\s]+/;  # ... in {VAR:...}, {FILE:...}, etc.

use constant SECTIONS => 0;
use constant SHASH    => 1;
use constant ATTRS    => 2;
use constant VAR      => 3;
use constant LOOP     => 4;
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
# LOOP:         { ... },
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
    $included = $parms{'included'}||$self->included();

    # see AUTOLOAD() for (almost) parallel list of attributes
    for( qw(
        interpolates expands
        inherits no_inherit no_override
        include_root keep_comments heredoc_style
        loop_limit size_limit encoding filter callbacks
        ) ) {
        no strict 'refs';  # so "$$_" will get above values
        $self->_attr( $_ =>
            (defined $parms{ $_ }) ? $parms{ $_ } : $$_ );
    }
    $self->_attr( file => $file ) if $file;

    my $inherits      = $self->inherits();
    my $no_override   = $self->no_override();
    my $keep_comments = $self->keep_comments();
    my $interpolates  = $self->interpolates();
    my $expands       = $self->expands();
    my $encoding      = $self->encoding();
    my $include_root  = $self->include_root();
    $self->include_root( $include_root )
        if $include_root =~ s'/+$'';  # strip trailing slash(es)

    unless( $fh ) {
        if( $string ) {
            if( $encoding ) {
                open $fh, "<:encoding($encoding)", \$string
                    or croak "Can't open string: $!";
            }
            else {
                open $fh, "<", \$string
                    or croak "Can't open string: $!";
            }
        }
        elsif( $file ) {
            if( $encoding ) {
                open $fh, "<:encoding($encoding)", $file
                    or croak "Can't open $file: $!";
            }
            else {
                open $fh, "<", $file
                    or croak "Can't open $file: $!";
            }
        }
        else { croak "Invalid parms" }
    }

    my $section = '';
    my $name = '';
    my $value;
    my %vattr;
    my $comment;
    my $pending_comments = '';
    my %i;  # per-value array indexes for value attributes
    my $resingle = qr/' (?:  '' | [^'] )* '/x;
    my $redouble = qr/" (?: \\" | [^"] )* "/x;
    my $requoted = qr/ $resingle|$redouble /xo;
    my $jit;  # just-in-time includes

    local *_;
    while( <$fh> ) {
        my $parse   = '';
        my $escape  = '';
        my $json    = '';
        my $heredoc = '';
        my $q       = '';

        #-------------------------------------------------------------
        # parse each line for comments, sections, and $name = $value
        # (no interpolations or expansions yet)
        # also get INCLUDE's (already interpolated/expanded)

        # comment or blank line
        if( /^ \s* [#;] /x or /^ \s* $/x ) {
            next unless $keep_comments;
            $pending_comments .= $_;
            next;
        }

        # [section]

        # (excluding {} because of Config::Ini::Expanded's
        # expansion syntax {INI:section:name} -- if section
        # contains {}, it's confusing for the code)

        if( /^ \[ ( [^{}\]]* ) \] ( \s* [#;] .* \s* )? /x ) {
            $section    = $1;
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
            /^ \s* ($requoted) (\s* [=:] \s*) (<<|{) \s* ([^}>] *?) \s* $/xo or
            /^ \s* ([^=:]+?)   (\s* [=:] \s*) (<<|{) \s* ([^}>] *?) \s* $/x  ) {
            $name            = $1;
            $vattr{'equals'} = $2;
            my $style        = $3;
            my $heretag      = $4;
            ( $q, $heretag, $comment ) = ( $1, $2, $3 )
               if $heretag =~ /^ (['"]) (.*) \1 (\s* [#;] .*)? /x;

            my $extra = '';
            my $indented    = ($heretag =~ s/ \s*  :indented \s* //x) ? 1  : '';
            my $join        = ($heretag =~ s/ \s*  :join     \s* //x) ? 1  : '';
            my $chomp       = ($heretag =~ s/ \s*  :chomp    \s* //x) ? 1  : '';
            $json           = ($heretag =~ s/ \s* (:json)    \s* //x) ? $1 : '';
            $escape        .= ($heretag =~ s/ \s* (:html)    \s* //x) ? $1 : '';
            $escape        .= ($heretag =~ s/ \s* (:slash)   \s* //x) ? $1 : '';
            $parse  = $1    if $heretag =~ s/ \s*  :parse    \s* \( \s* (.*?) \s* \) \s* //x;
            $parse  = '\n'  if $heretag =~ s/ \s*  :parse    \s* //x;
            $extra .= $1 while $heretag =~ s/ \s* (:\w+)     \s* //x; # strip unrecognized (future?) modifiers

            $value = '';
            my $endtag = $style eq '{' ? '}' : '<<';
            my $found_end;

            while( <$fh> ) {

                if( $heretag eq '' ) {
                    if( /^ \s* $endtag \s* $/x ) {
                        $style .= $endtag;
                        ++$found_end;
                    }
                }

                else {
                    if( /^ \s*    \Q$heretag\E    \s* $/x ||
                        /^ \s* $q \Q$heretag\E $q \s* $/x ){
                        ++$found_end;
                    }
                    elsif( /^ \s* $endtag \s*    \Q$heretag\E    \s* $/x ||
                           /^ \s* $endtag \s* $q \Q$heretag\E $q \s* $/x ){
                        $style .= $endtag;
                        ++$found_end;
                    }
                }

                last         if $found_end;
                chomp $value if $join;

                # we want to save an indentation value.
                # by convention, we'll save the first
                # string of white space we see here

                if( $indented ) {
                    if( s/^ (\s+) //x ) {
                        $indented = $1 if $indented !~ /^\s+$/;
                    }
                }

                $value .= $_;

            }  # while (heredoc loop)

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
        elsif( /^ \s* { INCLUDE: ( [^:{}]+ ) (?: : ([^:{}]+) )* } /x ) {
            my ( $file, $sections ) = ( $1, $2 );

            # checks for security
            croak "INCLUDE not allowed."
                if !$include_root                or  # no include root
                    $include_root =~ m'^ /+ $'x  or  # is root? '/'
                    $file         =~ m' \.\. 'x;     # file contains '..'

            $file =~ s'^ /+ ''x;             # remove leading slash
            $file = "$include_root/$file";   # put it back
            next if $included->{ $file }++;  # only include a file once
                                             # (avoids include loops)

            my $ini = Config::Ini::Expanded->new(
                include_root => $include_root,
                file         => $file,
                included     => $included );

            my @sections = $sections        ?
                split( /[, ]+/, $sections ) :
                $ini->get_sections();

            # merge that one into this one
            # note: we're not keeping comments, attributes, etc.
            #       from the included file

            foreach my $section ( @sections ) {
                foreach my $name ( $ini->get_names( $section ) ) {
                    $self->add( $section, $name,
                        $ini->get( $section, $name ) );
                }
            }
            next;
        }

        # {JIT:file}
        elsif( /^ \s* { JIT: ( [^:{}]+ ) } /x ) {
            my $file = $1;

            # checks for security
            croak "JIT not allowed."
                if !$include_root                or  # no include root
                    $include_root =~ m'^ /+ $'x  or  # is root? '/'
                    $file         =~ m' \.\. 'x;     # file contains '..'

            $file =~ s'^ /+ ''x;             # remove leading slash
            $file = "$include_root/$file";   # put it back

            push @{$jit->{ $section }}, $file;

            next;
        }

        # "name" = value
        elsif( /^ \s* ($requoted) (\s* [=:] \s*) (.*) $/xo ) {
            $name            = $1;
            $vattr{'equals'} = $2;
            $value           = $3;  # may contain comment
            $vattr{'nquote'} = substr $name, 0, 1;
        }

        # name = value
        elsif( /^ \s* ([^=:]+?) (\s* [=:] \s*) (.*) $/x ) {
            $name            = $1;
            $vattr{'equals'} = $2;
            $value           = $3;  # may contain comment
        }

        # "bare word" (treated as boolean set to true(1))
        else {
            s/^\s+//g; s/\s+$//g;  # strip blanks
            $name  = $_;
            $value = 1;  # may contain comment
        }

        # Here, we're saying that this ini file may not set
        # (i.e., override) the named option, because it may
        # only be set in a "parent" ini file.  So we simply
        # loop back to get a new line without adding this
        # name/value to this ini object

        if( $inherits and $no_override ) {
            if( $no_override->{ $section }{ $name } ) {

                # XXX possible future feature ...
                # croak "Section:$section/Name:$name may not be overridden"
                #     if $Config::Ini::Expanded::die_on_override;

                next;
            }
        }

        #-------------------------------------------------------------
        # now parse, interpolate, expand, json-ize, etc.

        my $quote = sub {
            my( $v, $q, $escape ) = @_;
            if( $q eq "'" ) { return &parse_single_quoted }  # note &
            else {
                $v = &parse_double_quoted;                   # note &
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

        elsif( $value =~ /^ ($requoted) ( \s* [#;] .* )? $/xo ) {
            my $quoted      = $1;
            $comment        = $2 if $2 and $keep_comments;
            my $q           = substr $quoted, 0, 1;
            $vattr{'quote'} = $q;
            $value          = $quote->( $quoted, $q, $escape );
        }

        # the following allows for "{INI:general:setting}" = some value
        # or "A rose,\n\tby another name,\n" = smells as sweet

        if( $name =~ /^ (['"]) .* \1 $/x ) {
            $name = $quote->( $name, $1 );
        }

        $vattr{'comment'} = $comment if $comment;
        $comment = '';

        # Note: this implies that we allow :parse or :json, not both ...

        if( $parse ne '' ) {
            $parse = $quote->( $parse, $1 )
                if $parse =~ m{^ ( ['"/] ) .* \1 $}x;

            # this may parse into multiple values
            $self->add( $section, $name,
                map { (defined $_) ? $_ : '' }
                parse_line( $parse, 0, $value ) );
        }
        else {
            # 'decode' is 'from json text to perl ref'

            # it is expected that the $value has already
            # been Encode::decode'd into perl's internal
            # character encoding (i.e., utf8), and that
            # this is what JSON::decode is expecting

            if( $json ) {
                if( $JSON::VERSION < 2 ) {
                    $JSON::BareKey = 1;  # *accepts* bare keys
                    $value = jsonToObj $value;
                }
                else {
                    my $jobj = JSON::->new;
                    $value = $jobj->decode( $value );
                }
            }
            $self->add( $section, $name, $value );
        }

        $self->vattr( $section, $name, $i{ $section }{ $name },
            %vattr ) if %vattr;
        %vattr = ();

        if( $pending_comments ) {
            $self->set_comments( $section, $name,
                $i{ $section }{ $name }, $pending_comments );
            $pending_comments = '';
        }

        $i{ $section }{ $name }++;

    }  # while (file loop)

    if( $pending_comments ) {
        $self->set_section_comments( '__END__', $pending_comments );
    }

    $self->included( $included ) if $included;
    $self->jit( $jit )           if $jit;
}

#---------------------------------------------------------------------
## $ini->get( $section, $name, $i )
# note: this is called in scalar context, so for multiple values, we
# just join them using $", i.e., "@values"
#
sub wrap_get {
    my ( $self, $section, $name, $i ) = @_;

    my $callbacks = $self->callbacks();
    unless( $callbacks ) {
        my @vals = &get;
        return "@vals";
    }

    my $cb_regx = join '|', keys %$callbacks;
    unless( $name =~ /^($cb_regx)\((.*)\)/ ) {
        my @vals = &get;
        return "@vals";
    }

    my $callback = $callbacks->{ $1 };
    my $realname =               $2;

    my @vals = $self->get( $section, $realname, $i );
    return $callback->( "@vals" ) if @vals;

    return;
}

sub get {
    my ( $self, $section, $name, $i ) = @_;

    return unless defined $section;

    # i.e., $ini->get( $name ); (get name from null section)
    ( $name = $section, $section = '' ) unless defined $name;

    # if not defined here, try to inherit ...
    #     (need to test like this to avoid autovivifications)
    unless(
        exists $self->[SHASH]{ $section } and
        exists $self->[SHASH]{ $section }[NHASH]{ $name } ) {

        # JIT includes here

        my  $jit;
        if( $jit = $self->jit() and
            $jit->{ $section }  and
          @{$jit->{ $section }} ) {

            my $included     = $self->included();
            my $include_root = $self->include_root();

            # merge include files until we get the value we
            # want or run out of files

            while( my $file = pop @{$jit->{ $section }} ) {
                next if $included->{ $file }++;

                my $ini = Config::Ini::Expanded->new(
                    include_root => $include_root,
                    file         => $file,
                    included     => $included );

                # merge that one into this one
                # note: we're not keeping comments, attributes,
                #       etc. from the included file
                # also, this should prompt JIT includes in the
                # included file, but won't add any to this object

                for my $sect ( $ini->get_sections() ) {
                    for my $nme ( $ini->get_names( $sect ) ) {
                        $self->add( $sect, $nme,
                            $ini->get( $sect, $nme ) );
                    }
                }

                if( wantarray ) {
                    my @try = $self->get( $section, $name, $i );  # recurse
                    return @try if @try;
                }
                else {
                    my $try = $self->get( $section, $name, $i );  # recurse
                    return $try if defined $try;
                }
            }
        }

        return unless $self->inherits();

        # check for prohibitions
        if( my $no_inherit = $self->no_inherit() ) {
            return if $no_inherit->{ $section }{ $name };
        }

        # now try to inherit
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

        return;  # i.e., not found in parents or jit includes
    }

    my $aref = $self->[SHASH]{ $section }[NHASH]{ $name }[VALS];

    return   $aref->[ $i ] if defined $i;  # requested an occurence
    return  @$aref         if wantarray;   # want all occurences

    # Note, if there's just one, it could be a reference
    # (e.g., from :json), which is why we don't just "@$aref" it

    return @$aref == 1 ? $aref->[ 0 ]: [ @$aref ];
}

#---------------------------------------------------------------------
## $ini->get_var( $var )
sub wrap_get_var {
    my ( $self, $var ) = @_;

    my $callbacks = $self->callbacks();
    return &get_var unless $callbacks;

    my $cb_regx = join '|', keys %$callbacks;
    return &get_var unless $var =~ /^($cb_regx)\((.*)\)/;

    my $callback = $callbacks->{ $1 };
    my $realvar  =               $2;

    for( $self->get_var( $realvar ) ) {
        return $callback->( $_ ) if defined;
    }

    return;
}

sub get_var {
    my ( $self, $var ) = @_;

    # if not defined here, try to inherit ...
    unless( defined $self->[VAR]       and
            defined $self->[VAR]{$var} ) {

        return unless $self->inherits();

        # now try to inherit
        #     (note that no_inherit does not apply here)
        for my $ini ( @{$self->inherits()} ) {
            my $try = $ini->get_var( $var );  # recurse
            return $try if defined $try;
        }

        return;  # i.e., not found in parents
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
## $ini->get_loop( $loop )
sub get_loop {
    my ( $self, $loop ) = @_;

    unless( defined $self->[LOOP]        and
            defined $self->[LOOP]{$loop} ) {

        return unless $self->inherits();

        # now try to inherit
        #     (note that no_inherit does not apply here)
        for my $ini ( @{$self->inherits()} ) {
            my $try = $ini->get_loop( $loop );  # recurse
            return $try if defined $try;
        }

        return;  # i.e., not found in parents
    }

    return $self->[LOOP]{$loop};
}

#---------------------------------------------------------------------
## $ini->set_loop( $loop, $value, ... )
#
# [1]: the following removes all loops set in the object
#
#      $ini->set_loop( undef );
#
# [2]: If the lname loop is set, the following removes it.  If the
#      lname loop isn't set, the following are all ignored -- i.e.
#      nothing is set and no errors occur.
#
#      [2.1] $ini->set_loop( { lname => undef } );
#      [2.2] $ini->set_loop(   lname => undef   );
#      [2.3] $ini->set_loop(   lname            );
#
# [3]: If the lname2 loop is set, the following removes it.  If the
#      lname2 loop isn't set, then the lname2 setting is ignored,
#      i.e., lname2 is not set and no errors occur.
#
#      [3.1] $ini->set_loop( { lname1 => 'val', lname2 => undef } );
#      [3.2] $ini->set_loop(   lname1 => 'val', lname2 => undef   );
#
# [4]: The following is an error
#
#      $ini->set_loop( lname1 => 'val', lname2 );
#

sub set_loop {
    my ( $self, @loops ) = @_;

    return unless @loops;

    if( @loops == 1 ) {
        if( not defined $loops[0] ) {
            delete $self->[LOOP];  # [1]
        }
        elsif( ref $loops[0] eq 'HASH' ) {
            my $href = $loops[0];
            while( my( $key, $val ) = each %$href ) {
                if( defined $val ) {
                    croak "set_loop(): '$key' is not a loop."
                        unless ref $val;
                    $self->[LOOP]{ $key } = $val if @$val;
                }
                else {
                    delete $self->[LOOP]{ $key }
                        if exists $self->[LOOP]{ $key };  # [2.1] [3.1]
                }
            }
        }
        else {
            for( $loops[0] ) {
                delete $self->[LOOP]{ $_ }
                    if exists $self->[LOOP]{ $_ };  # [2.3]
            }
        }
        return;
    }

    croak "set_loop(): Odd number of parms." if @loops % 2;  # [4]

    while( @loops ) {
        my $key = shift @loops;
        my $val = shift @loops;
        if( defined $val ) {
            croak "set_loop(): '$key' is not a loop."
                unless ref $val;
            $self->[LOOP]{ $key } = $val if @$val;
        }
        else {
            delete $self->[LOOP]{ $key }
                if exists $self->[LOOP]{ $key };  # [2.2], [3.2]
        }
    }
}

#---------------------------------------------------------------------
## $ini->get_expanded( $section, $name, $i )
sub get_expanded {
    my ( $self, $section, $name, $i ) = @_;

    my @ret = $self->get( $section, $name, $i );
    return unless @ret;

    for( @ret ) { $_ = $self->expand( $_, $section, $name ) }

    return @ret if wantarray;
    return @ret == 1 ? $ret[ 0 ]: \@ret;  # scalar context
}

#---------------------------------------------------------------------
## $ini->expand( $value, $section, $name )

# Note: two tags with the same name may not be (successfully) nested,
#       e.g.,
#
#       {IF_VAR:a}...{IF_VAR:a}...{END_IF_VAR:a}...{END_IF_VAR:a}
#
#       This would be parsed similar to the following:
#
#       {IF_VAR:a}...{IF_VAR:b}...{END_IF_VAR:a}...{END_IF_VAR:b}
#
#       and would not accomplish the (probably) desired result.
#
#       We take the liberal view: we don't object to the second badly
#       nested set of blocks, and we similarly don't object to the
#       first.  It's up to the user (in the current version anyway)
#       to detect a problem in the output.

sub expand {
    my ( $self, $value, $section, $name ) = @_;

    for( $self->filter() ) { $_->( \$value ) if defined; }
    my $loop_limit = $self->loop_limit()||$loop_limit;
    my $size_limit = $self->size_limit()||$size_limit;

    my $loops;
    while( 1 ) {  no warnings 'uninitialized';

        my $changes;

        # Note: The following call handles (IF|UNLESS)_(LVAR|LC)'s,
        #       too.  This is okay, because disambiguating ELSE's
        #       does not rely on whether or not we're in a LOOP
        #       context.

        if( $value =~ /{ELSE (?: : $Var_rx (?: : $Var_rx )* )? }/x ) {
            $changes += $value =~
                s/ (?<!!) ( { (IF|UNLESS) _ ([A-Z]+) :
                          ($Var_rx (?: : $Var_rx (?: : $Var_rx )* )? ) } )  # $1 (begin)
                          ( .*?                                          )  # $5 (inner)
                          ( { END_ \2 _ \3 : \4 }                        )  # $6 (end)
                          /$self->_disambiguate_else( $2, $3, $4, $5, $1, $6 )/goxes;
        }

        $changes += $value =~
            s/ (?<!!) { IF_VAR:          ($Var_rx) } (.*?)     # $2
                  (?: { ELSE_IF_VAR:     \1        } (.*?) )?  # $3
                      { END_IF_VAR:      \1        }
                      /$self->get_var( $1 )? $2: $3/goxes;
        $changes += $value =~
            s/ (?<!!) { UNLESS_VAR:      ($Var_rx) } (.*?)     # $2
                  (?: { ELSE_UNLESS_VAR: \1        } (.*?) )?  # $3
                      { END_UNLESS_VAR:  \1        }
                      /$self->get_var( $1 )? $3: $2/goxes;

        $changes += $value =~
            s/ (?<!!) { IF_INI:          ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
                  (?: { ELSE_IF_INI:     \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                      { END_IF_INI:      \1        : \2        (?: : \3        )? }
                      /$self->get( $1, $2, $3 )? $4: $5/goxes;
        $changes += $value =~
            s/ (?<!!) { UNLESS_INI:      ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
                  (?: { ELSE_UNLESS_INI: \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                      { END_UNLESS_INI:  \1        : \2        (?: : \3        )? }
                      /$self->get( $1, $2, $3 )? $5: $4/goxes;

        # this must come before IF/UNLESS_LOOP

        $changes += $value =~
            s/ (?<!!) { LOOP:     ($Var_rx) } (.*?)
                      { END_LOOP: \1        }
                      /$self->_expand_loop( $2, $1, $self->get_loop( $1 ) )/goxes;

        # Note: at this point no LOOP's have parents

        $changes += $value =~
            s/ (?<!!) { IF_LOOP:          ($Var_rx) } (.*?)     # $2
                  (?: { ELSE_IF_LOOP:     \1        } (.*?) )?  # $3
                      { END_IF_LOOP:      \1        }
                      /$self->get_loop( $1 )? $2: $3/goxes;
        $changes += $value =~
            s/ (?<!!) { UNLESS_LOOP:      ($Var_rx) } (.*?)     # $2
                  (?: { ELSE_UNLESS_LOOP: \1        } (.*?) )?  # $3
                      { END_UNLESS_LOOP:  \1        }
                      /$self->get_loop( $1 )? $3: $2/goxes;

        $changes += $value =~
            s/ (?<!!) { VAR: ($Var_rx) }
                      /$self->wrap_get_var( $1 )/goxe;
                      # was: /$self->get_var( $1 )/goxe;
        $changes += $value =~
            s/ (?<!!) { INI: ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? }
                      /$self->wrap_get( $1, $2, $3 )/goxe;
                      # was: /$self->get( $1, $2, $3 )/goxe;

        $changes += $value =~
            s/ (?<!!) { FILE: ($Var_rx) }
                      /$self->_readfile( $1 )/goxe;

        last unless $changes;

        if( ++$loops      > $loop_limit or
            length $value > $size_limit ) {
            my $suspect = '';
               $suspect = " ($1)" if $value =~ /(?<!!) (  # $1
                        {                    VAR:   $Var_rx   } |
                        {      (IF_|UNLESS_) VAR: ( $Var_rx ) } .*?
                        { END_ \2            VAR: \3          } |

                        {                    INI:   $Var_rx : $Var_rx (?: : $Var_rx )?   } |
                        {      (IF_|UNLESS_) INI: ( $Var_rx : $Var_rx (?: : $Var_rx )? ) } .*?
                        { END_ \4            INI: \5                                     } |

                        {                    LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_               LOOP: \6                           } |
                        {      (IF_|UNLESS_) LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_ \7            LOOP: \8                           } |

                        { FILE:  $Var_rx }
                        )/oxs;

            my $l = length $value;
            croak "expand(): Loop alert, '[$section]=>$name'$suspect ($loops) ($l): " .
                ( ( length($value) > 44 )? substr( $value, 0, 44 ).'...': $value );
        }

    }  # while

    # Undo postponements.
    # Note, these are outside the above while loop, because otherwise there
    # would be no point, i.e., the while loop would negate the postponements.

    # Note, LVAR and LC postponements (and qualified LOOP's) have to be done here,
    # too, because their postponed (outer) loop would not have been expanded yet.

    # XXX need tests to make sure this is correct

    for( $value ) {
        s/ !( {                    VAR:   $Var_rx    } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) VAR: ( $Var_rx ) } .*?
              { END_ \2            VAR: \3          } ) /$1/goxs;

        s/ !( {                    INI:   $Var_rx : $Var_rx (?: : $Var_rx )?   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) INI: ( $Var_rx : $Var_rx (?: : $Var_rx )? ) } .*?
              { END_ \2            INI: \3                                     } ) /$1/goxs;

        s/ !( {                    LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_               LOOP: \2                           } ) /$1/goxs;
        s/ !( {      (IF_|UNLESS_) LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LOOP: \3                           } ) /$1/goxs;

        s/ !( {                    LVAR:   (?: $Var_rx : )? $Var_rx   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) LVAR: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LVAR: \3                           } ) /$1/goxs;

        s/ !( {                    LC:     (?: $Var_rx : )? $Var_rx   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) LC:   ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LC:   \3                           } ) /$1/goxs;

        s/ !( { FILE:  $Var_rx } ) /$1/gox;
    }

    return $value;
}

#---------------------------------------------------------------------
## $ini->_expand_if()

sub _expand_if {
    my( $self, $name, $value ) = @_;

    my $loop_limit = $self->loop_limit()||$loop_limit;
    my $size_limit = $self->size_limit()||$size_limit;

    my $loops;
    while( 1 ) {  no warnings 'uninitialized';

        my $changes;

        $changes += $value =~
        s/ (?<!!) { IF_VAR:          ($Var_rx) } (.*?)     # $2
              (?: { ELSE_IF_VAR:     \1        } (.*?) )?  # $3
                  { END_IF_VAR:      \1        }
                  /$self->get_var( $1 )? $2: $3/goxes;
        $changes += $value =~
        s/ (?<!!) { UNLESS_VAR:      ($Var_rx) } (.*?)     # $2
              (?: { ELSE_UNLESS_VAR: \1        } (.*?) )?  # $3
                  { END_UNLESS_VAR:  \1        }
                  /$self->get_var( $1 )? $3: $2/goxes;

        $changes += $value =~
        s/ (?<!!) { IF_INI:          ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
              (?: { ELSE_IF_INI:     \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                  { END_IF_INI:      \1        : \2        (?: : \3        )? }
                  /$self->get( $1, $2, $3 )? $4: $5/goxes;
        $changes += $value =~
        s/ (?<!!) { UNLESS_INI:      ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
              (?: { ELSE_UNLESS_INI: \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                  { END_UNLESS_INI:  \1        : \2        (?: : \3        )? }
                  /$self->get( $1, $2, $3 )? $5: $4/goxes;

        $changes += $value =~
        s/ (?<!!) { IF_LOOP:          ($Var_rx) } (.*?)     # $2
              (?: { ELSE_IF_LOOP:     \1        } (.*?) )?  # $3
                  { END_IF_LOOP:      \1        }
                  /$self->get_loop( $1 )? $2: $3/goxes;
        $changes += $value =~
        s/ (?<!!) { UNLESS_LOOP:      ($Var_rx) } (.*?)     # $2
              (?: { ELSE_UNLESS_LOOP: \1        } (.*?) )?  # $3
                  { END_UNLESS_LOOP:  \1        }
                  /$self->get_loop( $1 )? $3: $2/goxes;

        last unless $changes;

        my $len = length $value;
        if( ++$loops > $loop_limit or
            $len     > $size_limit    ) {
            my $suspect = '';
               $suspect = " ($1)" if $value =~ /(?<!!) (  # $1
                    {      (IF_|UNLESS_) VAR:  ( $Var_rx ) } .*?
                    { END_ \2            VAR:  \3          } |
                    {      (IF_|UNLESS_) INI:  ( $Var_rx : $Var_rx (?: : $Var_rx )? ) } .*?
                    { END_ \4            INI:  \5                                     } |
                    {      (IF_|UNLESS_) LOOP: ( $Var_rx ) } .*?
                    { END_ \6            LOOP: \7          }
                    )/oxs;

            croak "_expand_loop(): Loop alert, '$name'$suspect ($loops) ($len): " .
                ( ( length($value) > 44 )? substr( $value, 0, 44 ).'...': $value );

        }
    }
    return $value;
}

#---------------------------------------------------------------------
## $ini->_expand_loop( $value, $name, $loop_aref, $contexts, $deep );

# Note: because of the current code logic, if you want to postpone
#       a loop that is in another loop, you must *also* postpone *all*
#       of the inner loop's lvar's and lc's, e.g.,
#       {LOOP:out}
#           !{LOOP:in} !{LVAR:in} !{LC:in:first} {END_LOOP:in}
#       {END_LOOP:out}

# Note: $contexts is an array of context hashes for the parents.
#       These allow a LOOP, LVAR, or LC to refer to an ancestor loop,
#       i.e., to inherit values contextually or explicitly.

sub _expand_loop {
    my ( $self, $value, $name, $loop_aref, $contexts, $deep ) = @_;

    my $loop_limit = $self->loop_limit()||$loop_limit;
    my $size_limit = $self->size_limit()||$size_limit;

    # catching deep recursion
    if( ++$deep > $loop_limit ) {
        croak "_expand_loop(): Deep recursion alert, '$name' ($deep): $value";
    }

    return unless defined $loop_aref;

    croak join ' ' =>
        "Error: for {LOOP:$name}, '$loop_aref' is not",
        "an array ref: $name => '$loop_aref'"
        unless ref $loop_aref eq 'ARRAY';

    unless( $contexts ) {
        $contexts = [];
    }

    my $context;
    $context->{ $name }{'last'} = $#{$loop_aref};

    # local array for find subs
    my @contexts = ( $context, @$contexts );

    my $callbacks = $self->callbacks();
    my $cb_regx;
    if( $callbacks ) {
        $cb_regx = join '|', keys %$callbacks;
    }

    # look for the loop in the current href, its parents,
    #     or the $ini object
    my $find_loop = sub {
        my( $in_loop, $lvar_name ) = @_;

        # if we're asking for a loop lvar in a specific loop ...
        if( defined $in_loop ) {
            for ( @contexts ) {
                if( exists $_->{ $in_loop } ) {
                    for ( $_->{ $in_loop }{'href'}{ $lvar_name } ) {
                        return $_ if defined and ref eq 'ARRAY';
                    }
                }
            }
            return;
        }

        # otherwise, look for that lvar in any of the current loops ...
        else {

            for ( @contexts ) {
                my( undef, $hash ) = %$_;
                for ( $hash->{'href'}{ $lvar_name } ) {
                    return $_ if defined and ref eq 'ARRAY';
                }
            }
            return $self->get_loop( $lvar_name );
        }

    };

    # look for the lvar in the current href or its parents
    my $find_lvar = sub {
        my( $in_loop, $lvar_name ) = @_;

        my $callback;
        if( $callbacks ) {
            if( $lvar_name =~ /^($cb_regx)\((.*)\)/ ) {
                $callback  = $callbacks->{ $1 };
                $lvar_name =               $2;
            }
        }

        # if we're asking for an lvar in a specific loop ...
        if( defined $in_loop ) {
            for ( @contexts ) {
                if( exists $_->{ $in_loop } ) {
                    for ( $_->{ $in_loop }{'href'}{ $lvar_name } ) {
                        if( defined ) {
                            return $callback->( $_ ) if $callback;
                            return              $_;
                        }
                    }
                }
            }
        }

        # otherwise, look for that lvar in any of the current loops ...
        else {
            for ( @contexts ) {
                my( undef, $hash ) = %$_;
                for ( $hash->{'href'}{ $lvar_name } ) {
                    if( defined ) {
                        return $callback->( $_ ) if $callback;
                        return              $_;
                    }
                }
            }
        }

        return;
    };

    my $loop_context = sub {
        my( $in_loop, $lc ) = @_;

        my $found;

        if( defined $in_loop ) {
            Look: for ( @contexts ) {
                for ( $_->{ $in_loop } ) {
                    if( defined ) { $found = $_; last Look }
                }
            }
        }

        # note: at this point, we don't have to look backward,
        # because the current context will always have the lc's

        else {
            $found = $context->{ $name };  # current context
        }

        return unless $found;
        my $i    = $found->{'index'};
        my $last = $found->{'last'};
        return  1   if $lc eq 'first' and $i == $[;
        return  1   if $lc eq 'last'  and $i == $last;
        return  1   if $lc eq 'inner' and $i > $[ and $i < $last;
        return  1   if $lc eq 'odd'   and !($i & 1);
        return $i   if $lc eq 'index';
        return $i+1 if $lc eq 'counter';
        if( $lc =~ /break\(([0-9]+)\)/ ) {
            my $n = $1;
            return   unless $n;
            return 1 unless ($i+1) % $n;
        }
        return;
    };

    # here's the meat
    my @ret;
    for my $i ( $[ .. $#{$loop_aref} ) {

        my $loop_href = $loop_aref->[ $i ];

        # allow a loop to be an array of scalars instead of an array
        # of hash refs, so the following would be the equivalent:
        #
        # loopx => [ 1, 2, 3 ]
        # loopx => [ { loopx => 1 }, { loopx => 2 }, { loopx => 3 } ]
        #
        # and you would say the following in both cases:
        #
        # {LOOP:loopx}{LVAR:loopx}{END_LOOP:loopx}

        unless( ref $loop_href eq 'HASH' ) {
            $loop_href = { $name => $loop_href };
        }

        $context->{ $name }{ 'href'  } = $loop_href;
        $context->{ $name }{ 'index' } = $i;

        my $tval = $value; 

        my $loops;
        while( 1 ) {  no warnings 'uninitialized';

            my $changes;

            # first, expand nested loops
            $changes += $tval =~ 
            s/ (?<!!) { IF_LOOP:          (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_IF_LOOP:     (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_IF_LOOP:      (?: \1        : )? \2        }
                      /$find_loop->( $1, $2 )? $3: $4/goxes;
            $changes += $tval =~ 
            s/ (?<!!) { UNLESS_LOOP:      (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_UNLESS_LOOP: (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_UNLESS_LOOP:  (?: \1        : )? \2        }
                      /$find_loop->( $1, $2 )? $4: $3/goxes;

            $changes += $tval =~ 
            s/ (?<!!) { LOOP:     (?: ($Var_rx) : )? ($Var_rx) } (.*?)  # $3
                      { END_LOOP: (?: \1        : )? \2        }
                      /$self->_expand_loop(  # recurse
                          $3,                         # $value
                          $2,                         # $name
                          $find_loop->( $1, $2 )||[], # $loop_aref
                          [ $context, @$contexts ],   # $contexts
                          $deep                       # for loop alert
                          )/goxes;

            # then the loop variables
            $changes += $tval =~ 
            s/ (?<!!) { IF_LVAR:          (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_IF_LVAR:     (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_IF_LVAR:      (?: \1        : )? \2        }
                      /$find_lvar->( $1, $2 )? $3: $4/goxes;
            $changes += $tval =~ 
            s/ (?<!!) { UNLESS_LVAR:      (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_UNLESS_LVAR: (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_UNLESS_LVAR:  (?: \1        : )? \2        }
                      /$find_lvar->( $1, $2 )? $4: $3/goxes;

            $changes += $tval =~ 
            s/ (?<!!) { LVAR: (?: ($Var_rx) : )? ($Var_rx) }
                      /$find_lvar->( $1, $2 )/goxe;

            # and the loop context values
            $changes += $tval =~ 
            s/ (?<!!) { IF_LC:          (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_IF_LC:     (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_IF_LC:      (?: \1        : )? \2        }
                      /$loop_context->( $1, $2 )? $3: $4/goxes;
            $changes += $tval =~ 
            s/ (?<!!) { UNLESS_LC:      (?: ($Var_rx) : )? ($Var_rx) } (.*?)     # $3
                  (?: { ELSE_UNLESS_LC: (?: \1        : )? \2        } (.*?) )?  # $4
                      { END_UNLESS_LC:  (?: \1        : )? \2        }
                      /$loop_context->( $1, $2 )? $4: $3/goxes;

            $changes += $tval =~ 
            s/ (?<!!) { LC: (?: ($Var_rx) : )? ($Var_rx) }
                      /$loop_context->( $1, $2 )/goxes;

            last unless $changes;

            if( ++$loops      > $loop_limit or
                length $value > $size_limit    ) {
                my $suspect = '';
                   $suspect = " ($1)" if $value =~ /(?<!!) (  # $1
                        {                    LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_               LOOP: \2                           } |
                        {      (IF_|UNLESS_) LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_ \3            LOOP: \4                           }
                        {                    LVAR:   (?: $Var_rx : )? $Var_rx   } |
                        {      (IF_|UNLESS_) LVAR: ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_ \5            LVAR: \6                           } |
                        {                    LC:     (?: $Var_rx : )? $Var_rx   } |
                        {      (IF_|UNLESS_) LC:   ( (?: $Var_rx : )? $Var_rx ) } .*?
                        { END_ \7            LC:   \8                           } |
                        )/oxs;

                my $l = length $value;
                croak "_expand_loop(): Loop alert, '$name'$suspect ($loops) ($l): " .
                    ( ( length($value) > 44 )? substr( $value, 0, 44 ).'...': $value );
            }
        }
        push @ret, $tval;
    }
    return join '' => @ret;
}

#---------------------------------------------------------------------
## $ini->_disambiguate_else(
##    $if_unless, $type, $name, $inner, $begin, $end );

# Notes:
#
# [1]: This code also disambiguates an ELSE that is qualified only
#      with a name, e.g., {IF_VAR:a} ... {ELSE:a} ... {END_IF_VAR:a}
#
# [2]: If there's an (unqualified) {ELSE} after recursing, it belongs
#      to us, i.e., to this call's outer IF/UNLESS block (i.e., the
#      one named $name).
#
# [3]: If there is an extraneous unqualifed {ELSE}, i.e., one that
#      is in the same IF/UNLESS block as that block's qualified
#      {ELSE...}, the unqualified {ELSE} is left alone -- whatever the
#      order it appears, i.e., it's not necessarily an error.
#
# [4]: If there are two or more (unqualified) {ELSE}'s, the first one
#      will be disambiguated and the rest left alone.  This should
#      not cause looping, because the IF/UNLESS's should be gone the
#      next time the ELSE is seen.

sub _disambiguate_else {
    my ( $self, $if_unless, $type, $name, $inner, $begin, $end ) = @_;

    # first, expand nested IF/UNLESS's by recursing (in case the {ELSE}
    # we saw is deeper down)
    $inner =~ 
        s/ (?<!!) ( { (IF|UNLESS) _ ([A-Z]+) :
                  ($Var_rx (?: : $Var_rx (?: : $Var_rx )* )? ) } )  # $1 (begin)
                  ( .*?                                          )  # $5 (inner)
                  ( { END_ \2 _ \3 : \4 }                        )  # $6 (end)
                  /$self->_disambiguate_else( $2, $3, $4, $5, $1, $6 )/goxes;

    # now look for any remaining unqualifed {ELSE}
    # [1] you can give an otherwise ambiguous {ELSE} a name with
    #     {ELSE:name}
    if( $inner =~ /{ELSE (?: : ( $Var_rx (?: : $Var_rx )* ))? }/x ) {
        my $given = $1;

        # [2]: disambiguate the ELSE
        my $explicit_else = "{ELSE_${if_unless}_$type:$name}";

        # [3]: unless there's already a qualified one
        unless( $inner =~ /$explicit_else/ ) {

            croak "Given name: '$given' does not match enclosing name: '$name'."
                if defined $given and $given ne $name; 

            # [4]: we're changing just the first one we find
            $inner =~ s/{ELSE (?: : $Var_rx (?: : $Var_rx )* )? }
                       /$explicit_else/x;

        }
    }

    return "$begin$inner$end";
}

#---------------------------------------------------------------------
## $ini->get_interpolated( $section, $name, $i )
sub get_interpolated {
    my ( $self, $section, $name, $i ) = @_;

    my @ret = $self->get( $section, $name, $i );
    return unless @ret;

    for( @ret ) { $_ = $self->interpolate( $_ ) };

    return @ret if wantarray;
    return @ret == 1 ? $ret[ 0 ]: \@ret;  # scalar context
}

#---------------------------------------------------------------------
## $ini->interpolate( $value )

sub interpolate {
    my( $self, $value ) = @_;

    for( $self->filter() ) { $_->( \$value ) if defined; }

    for ( $value ) {  no warnings 'uninitialized';

        if( /{ELSE (?: : $Var_rx (?: : $Var_rx )* )? }/x ) {
            s/ (?<!!) ( { (IF|UNLESS) _ ([A-Z]+) :
                      ($Var_rx (?: : $Var_rx (?: : $Var_rx )* )? ) } )  # $1 (begin)
                      ( .*?                                          )  # $5 (inner)
                      ( { END_ \2 _ \3 : \4 }                        )  # $6 (end)
                      /$self->_disambiguate_else( $2, $3, $4, $5, $1, $6 )/goxes;
        }

        s/ (?<!!) { IF_VAR:          ($Var_rx) } (.*?)     # $2
              (?: { ELSE_IF_VAR:     \1        } (.*?) )?  # $3
                  { END_IF_VAR:      \1        }
                  /$self->_expand_if( $1, $self->get_var( $1 )? $2: $3 )/goxes;
        s/ (?<!!) { UNLESS_VAR:      ($Var_rx) } (.*?)     # $2
              (?: { ELSE_UNLESS_VAR: \1        } (.*?) )?  # $3
                  { END_UNLESS_VAR:  \1        }
                  /$self->_expand_if( $1, $self->get_var( $1 )? $3: $2 )/goxes;

        s/ (?<!!) { IF_INI:          ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
              (?: { ELSE_IF_INI:     \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                  { END_IF_INI:      \1        : \2        (?: : \3        )? }
                  /$self->_expand_if( "$1:$2:$3", $self->get( $1, $2, $3 )? $4: $5 )/goxes;
        s/ (?<!!) { UNLESS_INI:      ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? } (.*?)     # $4
              (?: { ELSE_UNLESS_INI: \1        : \2        (?: : \3        )? } (.*?) )?  # $5
                  { END_UNLESS_INI:  \1        : \2        (?: : \3        )? }
                  /$self->_expand_if( "$1:$2:$3", $self->get( $1, $2, $3 )? $5: $4 )/goxes;

        # this must come before IF/UNLESS_LOOP

        s/ (?<!!) { LOOP:     ($Var_rx) } (.*?)
                  { END_LOOP: \1        }
                  /$self->_expand_loop( $2, $1, $self->get_loop( $1 ) )/goxes;

        # Note: at this point no LOOP's have parents

        s/ (?<!!) { IF_LOOP:          ($Var_rx) } (.*?)     # $2
              (?: { ELSE_IF_LOOP:     \1        } (.*?) )?  # $3
                  { END_IF_LOOP:      \1        }
                  /$self->_expand_if( $1, $self->get_loop( $1 )? $2: $3 )/goxes;
        s/ (?<!!) { UNLESS_LOOP:      ($Var_rx) } (.*?)     # $2
              (?: { ELSE_UNLESS_LOOP: \1        } (.*?) )?  # $3
                  { END_UNLESS_LOOP:  \1        }
                  /$self->_expand_if( $1, $self->get_loop( $1 )? $3: $2 )/goxes;

        s/ (?<!!) { VAR: ($Var_rx) }
                  /$self->wrap_get_var( $1 )/goxe;
                  # was: /$self->get_var( $1 )/goxe;
        s/ (?<!!) { INI: ($Var_rx) : ($Var_rx) (?: : ($Var_rx) )? }
                  /$self->wrap_get( $1, $2, $3 )/goxe;
                  # was: /$self->get( $1, $2, $3 )/goxe;
        s/ (?<!!) { FILE: ($Var_rx) }
                  /$self->_readfile( $1 )/goxe;

        # Undo postponements.
        s/ !( {                    VAR:   $Var_rx    } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) VAR:  ( $Var_rx ) } .*?
              { END_ \2            VAR:  \3          } ) /$1/goxs;

        s/ !( {                    INI:   $Var_rx : $Var_rx (?: : $Var_rx )?   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) INI: ( $Var_rx : $Var_rx (?: : $Var_rx )? ) } .*?
              { END_ \2            INI: \3                                     } ) /$1/goxs;

        s/ !( {                    LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_               LOOP: \2                           } ) /$1/goxs;
        s/ !( {      (IF_|UNLESS_) LOOP: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LOOP: \3                           } ) /$1/goxs;

        s/ !( {                    LVAR:   (?: $Var_rx : )? $Var_rx   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) LVAR: ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LVAR: \3                           } ) /$1/goxs;

        s/ !( {                    LC:     (?: $Var_rx : )? $Var_rx   } ) /$1/gox;
        s/ !( {      (IF_|UNLESS_) LC:   ( (?: $Var_rx : )? $Var_rx ) } .*?
              { END_ \2            LC:   \3                           } ) /$1/goxs;

        s/ !( { FILE:  $Var_rx } ) /$1/gox;
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
    $file =~ s'^/+'';
    $file = "$include_root/$file";
    my $fh;
    if( my $encoding = $self->encoding() ) {
        open $fh, "<:encoding($encoding)", $file
            or croak "Can't open $file: $!";
    }
    else {
        open $fh, "<", $file
            or croak "Can't open $file: $!";
    }
    local $/;
    return <$fh>;
}

#---------------------------------------------------------------------
## AUTOLOAD() (wrapper for _attr())
## file( $filename )
## include_root( $include_root )
## encoding( 'utf8' )
## interpolates( 1 )
## expands( 1 )
## inherits( [$ini_obj1,$ini_obj2,...] )
## no_inherit(  { section1=>{name1=>1,name2=>1}, s2=>{n3=>1}, ... } )
## no_override( { section1=>{name1=>1,name2=>1}, s2=>{n3=>1}, ... } )
## keep_comments( 0 )
## heredoc_style( '<<' )
## loop_limit( 10 )
## size_limit( 1_000_000 )
## filter( \&filter_sub )
## callbacks( { abc => \&abc, xyz => \&xyz, ... } ), i.e., hash of subs
## included( { file1 => 1, file2 => 1, ... } )
## jit( { sect1 => [file1,file2,...], sect2 => [file3,...], ... } )
our $AUTOLOAD;
sub AUTOLOAD {
    my $attribute = $AUTOLOAD;
    $attribute =~ s/.*:://;

    # see init() for (almost) parallel list of attributes
    die "Undefined: $attribute()" unless $attribute =~ /^(?:
        file | include_root | encoding |
        interpolates | expands |
        inherits | no_inherit | no_override |
        keep_comments | heredoc_style |
        loop_limit | size_limit |
        filter | callbacks |
        included | jit
        )$/x;

    my $self = shift;
    $self->_attr( $attribute, @_ );
}
sub DESTROY {}


#---------------------------------------------------------------------
1;

__END__
