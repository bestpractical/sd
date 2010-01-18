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

after out_record => sub {
    my $self = shift;
    my $record = shift;

    my $keys = $self->out_widget( $record );
    ASK_AGAIN:
    print "Update> ";

    my $action = <>;
    chomp $action;
    $action =~ s/^\s+//;
    $action =~ s/\s+$//;

    return unless length $action;

    my $do = $keys->{ $action };
    unless ( $do ) {
        print "No action binded to '$action', try again...\n";
        goto ASK_AGAIN;
    }

    if ( $do->{'action'} eq 'status' ) {
        $record->set_prop( name => 'status', value => $do->{'value'} );
        print "Done\n";
    }
    else {
        print "Not implemented, patches are welcome\n";
        goto ASK_AGAIN;
    }
};

sub out_widget {
    my $self = shift;
    my $record = shift;
    my %keys = (
        b => { line => 0, order => 0, action => 'show', value=> 'basics', display => 'show [b]asics' },
        d => { line => 0, order => 1, action => 'show', value=> 'details', display => '[d]etails' },
        m => { line => 1, order => 0, action => 'milestone', display => '[m]ilestone' },
        c => { line => 1, order => 1, action => 'component', display => '[c]omponent' },
    );
    {
        my $order = 0;
        my @statuses = @{ $record->app_handle->setting( label => 'statuses' )->get };
        foreach my $status ( @statuses ) {
            my $letter = ''; my $pos = 0;
            do {
                $letter = substr $status, $pos++, 1;
            } while ( exists $keys{$letter} && $pos < length $status );
            
            my $display = $status;
            substr $display, $pos-1, 0, '[';
            substr $display, $pos+1, 0, ']';
            $keys{$letter} = {
                line => 2, order => $order++,
                action => 'status', value => $status,
                display => $display,
            };
        }
    }

    my $status = $record->prop('status');

    my $res = '';
    my $line = 0;
    foreach my $key ( sort {$a->{'line'} <=> $b->{'line'} || $a->{'order'} <=> $b->{'order'}} values %keys ) {
        next if $key->{'action'} eq 'status' && $key->{'value'} eq $status;

        if ( $key->{'line'} != $line ) {
            print $res, "\n";
            $res = '';
            $line = $key->{'line'};
        }
        
        $res .= ', ' if $res;
        $res .= $key->{'display'};
    }
    print $res, "\n";

    return \%keys;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

