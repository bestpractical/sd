package App::SD::CLI::Command::Ticket::Review;
use Any::Moose;
extends 'App::SD::CLI::Command::Ticket::Search';
#with 'App::SD::CLI::Command';

override usage_msg => sub {
    my $self = shift;
    my $script = $self->cli->get_script_name;

    my @primary_commands = @{ $self->context->primary_commands };

    # if primary commands was only length 1, the type was not specified
    # and we should indicate that a type is expected
    push @primary_commands, '<record-type>' if @primary_commands <= 1;

    my $type_and_subcmd = join( q{ }, @primary_commands );

    return <<"END_USAGE";
usage: ${script}${type_and_subcmd}
       ${script}${type_and_subcmd} -- summary=~foo status!~new|open
END_USAGE
};

before run => sub {
    Prophet::CLI->end_pager();
};

our %ACTIONS = ();

our %INFO = (

);

after out_record => sub {
    my $self = shift;
    my $record = shift;

    $self->out_widget( $record );
    ASK_AGAIN:
    print "Update> ";

    my $do = <STDIN>;
    chomp $do;
    $do =~ s/^\s+//;
    $do =~ s/\s+$//;
    return unless length $do;

    my @list = split /\+/, $do;

    my $ask_again = 0;
    foreach my $do ( @list ) {
        my $action = $ACTIONS{ $do };
        unless ( $action ) {
            print "No action bound to '$do', try again...\n";
            $ask_again = 1; next;
        }
        next unless $action->{'action'};

        my $name = 'action_'. $action->{'action'};
        unless ( $self->can($name) ) {
            print "Not implemented, patches are welcome\n";
            $ask_again = 1; next;
        }

        $self->$name( $record, %$action );
        print "Done $do\n";
    }
    goto ASK_AGAIN if $ask_again;
};

sub out_widget {
    my $self = shift;
    my $record = shift;

    $self->prepare_actions($record) unless keys %ACTIONS;
    
    print "show [b] basics or [d] details\n";
    foreach my $property ( @{ $INFO{'properties'} } ) {
        my $prop_shortcut = $INFO{'shortcuts'}{$property};
        print "$property:\n";
        print "\t";
        my $current = $record->prop($property);
        my $not_first = 0;
        foreach my $value ( @{ $INFO{'values'}{$property} } ) {
            print ", " if $not_first++;
            print "[". $prop_shortcut . $INFO{vshortcuts}{$property}{$value} ."] $value";
            print "*" if $value eq $current;
        }
        print "\n";
    }
}

sub action_property {
    my $self = shift;
    my $record = shift;
    my %args = ( name => undef, value => undef, @_ );
    $record->set_prop( name => $args{'name'}, value => $args{'value'} );
}

sub prepare_actions {
    my $self = shift;
    my $record = shift;

    %ACTIONS = (
        b => { action => 'show', value => 'basics' },
        d => { action => 'show', value => 'details' },
    );

    my @reserved = keys %ACTIONS;
    my $app_handle = $record->app_handle;
    my @props = @{ $app_handle->setting( label => 'common_ticket_props' )->get };

    foreach my $property ( @props ) {
        my $plural_form = $self->plural_noun( $property );
        # XXX: dirty hack
        next unless $app_handle->database_settings->{$plural_form};

        my @values = @{ $app_handle->setting( label => $plural_form )->get };
        next unless @values;

        $INFO{'values'}{$property} = \@values;

        my $shortcut = $INFO{'shortcuts'}{$property}
            = $self->shortcut( $property, @reserved );
        push @reserved, $shortcut;
        $ACTIONS{ $shortcut } = {};
    }

    @props = grep $INFO{'values'}{ $_ }, @props;
    $INFO{'properties'} = \@props;

    foreach my $property ( @props ) {
        my @reserved = ();
        foreach my $value ( @{ $INFO{'values'}{$property} } ) {
            my $shortcut = $self->shortcut( $value, @reserved );
            push @reserved, $shortcut;
            
            $ACTIONS{ $INFO{'shortcuts'}{$property} . $shortcut } = {
                action => 'property', name => $property, value => $value, 
            };
            $INFO{'vshortcuts'}{$property}{$value} = $shortcut;
        }
    }
}

sub plural_noun {
    my $self = shift;
    my $noun = shift;

# simple plural form generation, full info on
# http://www.csse.monash.edu.au/~damian/papers/HTML/Plurals.html

    return $noun.'es' if $noun =~ /[cs]h$/;
    return $noun.'es' if $noun =~ /ss$/;
    return $noun      if $noun =~ s/([aeo]l|[^d]ea|ar)f$/$1ves/;
    return $noun      if $noun =~ s/([nlw]i)fe$/$1ves/;
    return $noun.'s'  if $noun =~ /[aeiou]y$/;
    return $noun      if $noun =~ s/y$/ies/;
    return $noun.'s'  if $noun =~ /[aeiou]o$/;
    return $noun.'es' if $noun =~ /o$/;
    return $noun.'es' if $noun =~ /s$/;
    return $noun.'s';
}

sub shortcut {
    my $self = shift;
    my $word = shift;
    my @reserved = @_;

    for (my $i = 0; $i < length $word; $i++ ) {
        my $char = substr $word, $i, 1;
        return wantarray? ($char, $i) : $char
            unless grep $_ eq $char, @reserved; 
    }
    for (my $i = 1; $i <= length $word; $i++ ) {
        my $prefix = substr $word, 0, $i;
        return wantarray? ($prefix, $i) : $prefix
            unless grep $_ eq $prefix, @reserved;
    }
    return $word, 0;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
