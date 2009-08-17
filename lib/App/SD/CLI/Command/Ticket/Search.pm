package App::SD::CLI::Command::Ticket::Search;
use Any::Moose;
extends 'Prophet::CLI::Command::Search';
with 'App::SD::CLI::Command';

sub ARG_TRANSLATIONS { shift->SUPER::ARG_TRANSLATIONS(),  s => 'sort', g => 'group'  };

sub usage_msg {
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
}

# frob the sort routine before running prophet's search command
sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    if (  (!$self->has_arg('sort') || !$self->arg('sort'))
        && $self->app_handle->config->get( key => 'ticket.default-sort') )
    {
        $self->set_arg(
            'sort' => $self->app_handle->config->get(
                key => 'ticket.default-sort'
            )
        );
    }

    if (  (!$self->has_arg('group') || !$self->arg('group'))
        && $self->app_handle->config->get( key => 'ticket.default-group') )
    {
        $self->set_arg( 'group' =>
              $self->app_handle->config->get( key => 'ticket.default-group') );
    }

    # sort output by given prop if user specifies --sort
    if ( $self->has_arg('sort') && $self->arg('sort')
            && ( $self->arg('sort') ne 'none' ) ) {

        $self->sort_routine(
            sub {
                my $records = shift;
                return $self->sort_by_prop( $self->arg('sort') => $records );
            }
        );
    }

    if ( $self->has_arg('group') && $self->arg('group') && (
            $self->arg('group') ne 'none' ) ) {
        $self->group_routine(
            sub {
                my $records = shift;
                my $groups =
                  $self->group_by_prop( $self->arg('group') => $records );
                if ( $self->arg('group') eq 'milestone' ) {
                    my $order =
                      $self->app_handle->setting( label => 'milestones' )
                      ->get();
                    my %group_hash =
                      map { $_->{'label'} => $_->{'records'} } @$groups;
                    my $sorted_groups = [
                        map {

                            {
                                label   => $_,
                                records => ( delete $group_hash{$_} || [] )
                            }

                          } @$order
                    ];
                    return [
                        @$sorted_groups,
                        (
                            map { { label => $_, records => $group_hash{$_} } }
                              keys %group_hash
                        )
                    ];
                }
                return $groups;
            }
        );
    }
    $self->SUPER::run(@_);
}

# implicit status != closed
sub default_match {
    my $self   = shift;
    my $ticket = shift;

    return 1 if $ticket->has_active_status();
    return 0;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

