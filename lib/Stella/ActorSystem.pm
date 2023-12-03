
use v5.38;
use experimental 'class', 'try', 'builtin';
use builtin qw[ blessed refaddr ];

class Stella::ActorSystem {
    use Time::HiRes 'sleep';
    use Carp        'confess';

    use IO::Select;

    use Stella::Tools::Debug;

    my $PIDS = 0;

    field %actor_refs;     # PID => ActorRef mapping of active Actors
    field %actor_registry; # Name => ActorRef mapping

    field %watchers;  # r/w => FD => list of I/O Watcher objects
    field @callbacks; # queue of callbacks to be run in a given tick
    field @timers;    # queue of Timer/Interval objects to run

    field $init    :param; # function that accepts ActorContext($init_ref) as its only argument
    field $mailbox :param = Stella::Core::Mailbox->new;

    field $init_ref;
    field $select;
    field $logger;

    field $time = 0; # the current time, using Time::HiRes
    field $tick = 0; # the current tick of the loop

    ADJUST {
        $mailbox isa Stella::Core::Mailbox || confess 'The `mailbox` must be a Stella::Core::Mailbox';

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;

        # set up the I/O stuff
        $select   = IO::Select->new;
        %watchers = ( r => {}, w => {} );
    }

    ## ...

    ## ------------------------------------------------------------------------
    ## Process Management
    ## ------------------------------------------------------------------------

    method register_actor ($name, $actor_ref) {
        $actor_registry{ $name } = $actor_ref;
    }

    method lookup_actor ($name) {
        $actor_registry{ $name } || $actor_refs{ $name }
    }

    method spawn ($actor_props) {
        $actor_props isa Stella::ActorProps || confess 'The `$actor_props` arg must be an Stella::ActorProps';

        my $a = Stella::ActorRef->new( pid => ++$PIDS, actor_props => $actor_props );
        $actor_refs{ $a } = $a;

        $logger->log_from(
            $init_ref, DEBUG,
            (sprintf "Spawning ACTOR(%s) REF(%s)" => "$actor_props", "$a"),
            " >> caller: ".(caller(2))[3]
        ) if DEBUG && $init_ref;

        $a->start;
        $a;
    }

    method despawn ($actor_ref, $immediate=0) {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` arg must be an ActorRef';

        $logger->log_from(
            $init_ref, DEBUG,
            (sprintf "Request despawning of REF(%s)" => "$actor_ref"),
            " >> caller: ".(caller(2))[3]
        ) if DEBUG;

        if ($immediate) {
            $logger->log_from( $init_ref, DEBUG, "Immediate!! Despawning REF($actor_ref)") if DEBUG;
            $actor_ref->stop;
            delete $actor_refs{ $actor_ref };
        }
        else {
            # add this to the front of the queue
            # for the next-tick to make sure it
            # is done as soon as possible after
            # this tick
            unshift @callbacks => sub {
                $logger->log_from( $init_ref, DEBUG, "... Despawning REF($actor_ref)") if DEBUG;
                $actor_ref->stop;
                delete $actor_refs{ $actor_ref };
            };
        }
    }

    ## ------------------------------------------------------------------------
    ## Messages
    ## ------------------------------------------------------------------------


    method enqueue_message ($message) {
        $mailbox->enqueue_message( $message );

        $logger->log_from(
            $init_ref, DEBUG,
            (sprintf "Enqueue Message TO(%s) FROM(%s) EVENT(%s)" =>
                $message->to,
                $message->from,
                $message->event,
            ),
            " >> caller: ".(caller(2))[3]
        ) if DEBUG;
    }

    method add_to_dead_letter ($reason, $message) {
        $mailbox->add_dead_letter( $reason, $message );

        $logger->log_from(
            $init_ref, ERROR,
            "Adding MSG($message) to Dead Letter Queue because ($reason)"
        ) if ERROR;
    }


    ## ------------------------------------------------------------------------
    ## I/O watchers
    ## ------------------------------------------------------------------------

    method add_watcher ($watcher) {
        $watcher isa Stella::Core::Watcher || confess 'The `$watcher` arg must be a Watcher';

        $logger->log_from( $init_ref, DEBUG,
            (sprintf "Adding `%s` watcher for fh(%s)" => $watcher->poll, $watcher->fh)
        ) if DEBUG;

        my ($poll, $fh) = ($watcher->poll, $watcher->fh);

        # initialist structure for the fh if needed ...
        $watchers{ $poll }->{ $fh } //= [];
        push @{ $watchers{ $poll }->{ $fh } } => $watcher;

        # Only add it to select if it hasn't already been added
        $select->add( $fh ) unless $select->exists( $fh );
    }

    method remove_watcher ($watcher) {
        $watcher isa Stella::Core::Watcher || confess 'The `$watcher` arg must be a Watcher';

        my ($poll, $fh) = ($watcher->poll, $watcher->fh);

        exists $watchers{ $poll } || confess 'Watcher not found, no poll('.$poll.') watchers registered';
        exists $watchers{ $poll }->{ $fh }
            || confess 'Watcher not found, no poll('.$poll.') => fh('.$fh.') watchers registered';

        my $watchers = $watchers{ $poll }->{ $fh };

        (scalar grep { refaddr $_ eq refaddr $watcher } @$watchers)
            || confess 'Watcher not found, no matching watcher('.$watcher.') for poll('.$poll.') => fh('.$fh.')';

        $logger->log_from( $init_ref, DEBUG,
            (sprintf "Removing `%s` watcher for fh(%s)" => $poll, $fh)
        ) if DEBUG;

        # remove the watcher ...
        @$watchers = grep { refaddr $_ ne refaddr $watcher } @$watchers;

        # if there are no other watchers ...
        unless (@$watchers) {
            # remove the fh from the structure
            delete $watchers{ $poll }->{ $fh };
            # and remove it from the select
            $select->remove( $fh );
        }
    }

    ## ------------------------------------------------------------------------
    ## Timers
    ## ------------------------------------------------------------------------

    method now  {
        state $MONOTONIC = Time::HiRes::CLOCK_MONOTONIC();
        # always stay up to date ...
        $time = Time::HiRes::clock_gettime( $MONOTONIC );
    }

    method schedule_timer ($timer) {

        # XXX - should this use $time, or should it call ->now to update?
        my $end_time = $timer->calculate_end_time($self->now);

        if ( scalar @timers == 0 ) {
            # fast track the first one ...
            push @timers => [ $end_time, [ $timer ] ];
        }
        # if the last one is the same time as this one
        elsif ( $timers[-1]->[0] == $end_time ) {
            # then push it onto the same timer slot ...
            push $timers[-1]->[1]->@* => $timer;
        }
        # if the last one is less than this one, we add a new one
        elsif ( $timers[-1]->[0] < $end_time ) {
            push @timers => [ $end_time, [ $timer ] ];
        }
        elsif ( $timers[-1]->[0] > $end_time ) {
            # and only sort when we absolutely have to
            @timers = sort { $a->[0] <=> $b->[0] } @timers, [ $end_time, [ $timer ] ];
            # TODO: since we are sorting we might
            # as well also prune the cancelled ones
        }
        else {
            # NOTE:
            # we could add some more cases here, for instance
            # if the new time is before the last timer, we could
            # also check the begining of the list and `unshift`
            # it there if it made sense, but that is likely
            # micro optimizing this.
            die "This should never happen";
        }
    }

    method get_next_timer () {
        while (my $next_timer = $timers[0]) {
            # if we have any timers
            if ( $next_timer->[1]->@* ) {
                # if all of them are cancelled
                if ( 0 == scalar grep !$_->cancelled, $next_timer->[1]->@* ) {
                    # drop this set of timers
                    shift @timers;
                    # try again ...
                    next;
                }
                else {
                    last;
                }
            }
            else {
                shift @timers;
            }
        }

        return $timers[0];
    }

    ## ------------------------------------------------------------------------
    ## The TICK
    ## ------------------------------------------------------------------------

    method tick {
        # timers ...

        my $now = $self->now;

        if ( @timers ) {
            my @intervals;
            $logger->log_from( $init_ref, DEBUG, "Got timers ...") if DEBUG;
            while (@timers && $timers[0]->[0] <= $now) {
                $logger->log_from( $init_ref, DEBUG, "Running timers ($now) ...") if DEBUG;
                my $timer = shift @timers;
                while ( $timer->[1]->@* ) {
                    my $t = shift $timer->[1]->@*;
                    next if $t->cancelled; # skip if the timer has been cancelled
                    try {
                        $t->callback->();
                    } catch ($e) {
                        die "Timer callback failed ($timer) because: $e";
                    }
                    push @intervals => $t
                        if $t isa Stella::Core::Timer::Interval
                        && !$t->cancelled;
                }
            }

            $self->schedule_timer( $_ ) foreach @intervals;
        }

        # callbacks ...

        if ( @callbacks ) {
            my @cbs = @callbacks;
            @callbacks = ();

            while (@cbs) {
                my $f = shift @cbs;
                try {
                    $f->();
                } catch ($e) {
                    die "Callback failed ($f) because: $e";
                }
            }
        }

        # messages ...

        if ($mailbox->has_messages) {
            my @msgs = $mailbox->drain_messages;
            while (@msgs) {
                my $msg = shift @msgs;
                if ( my $actor_ref = $actor_refs{ $msg->to } ) {
                    try {
                        $actor_ref->apply(
                            # TODO: memoize the Context objects
                            Stella::Core::Context->new(
                                actor_ref => $actor_ref,
                                system    => $self
                            ),
                            $msg
                        );
                    } catch ($e) {
                        $self->add_to_dead_letter( $e => $msg );
                    }
                }
                else {
                    $self->add_to_dead_letter( 'ACTOR NOT FOUND' => $msg );
                }
            }
        }
    }

    method check_watchers ($wait) {

        local $! = 0;

        my $start = $self->now;

        my @handles = IO::Select::select(
            keys %{$watchers{r}} ? $select : undef,
            keys %{$watchers{w}} ? $select : undef,
            $select,
            $wait
        );

        # update the clock
        my $now = $self->now;

        # deal with errors and timeouts now ...
        if (scalar @handles == 0) {
            confess "Got error from select: $!" if $!;

            # otherwise ... we hit the timeout
            $logger->log_from( $init_ref, DEBUG, "Woke up from timeout($wait)") if DEBUG;
            # ... return early
            return;
        }


        # we have handles
        $logger->log_from( $init_ref, DEBUG, "Woke up by select event after (".($now - $start).")") if DEBUG;
        my ($r, $w, $e) = @handles;

        my @watchers;

        if (defined $w && @$w) {
            $logger->log_from( $init_ref, DEBUG, "Got write handles") if DEBUG;
            foreach my $fh ( @$w) {
                if ( my $ws = $watchers{w}->{ $fh } ) {
                    $logger->log_from( $init_ref, DEBUG, "Found write watchers for fh($fh)") if DEBUG;
                    push @watchers => [ $fh, $ws ];
                }
            }
        }
        elsif (defined $r && @$r) {
            $logger->log_from( $init_ref, DEBUG, "Got read handles") if DEBUG;
            foreach my $fh ( @$r ) {
                if ( my $ws = $watchers{r}->{ $fh } ) {
                    $logger->log_from( $init_ref, DEBUG, "Found read watchers for fh($fh)") if DEBUG;
                    push @watchers => [ $fh, $ws ];
                }
            }
        }
        elsif (defined $e && @$e) {
            $logger->log_from( $init_ref, DEBUG, "Got exception handles") if DEBUG;
            die 'Should not get a exception select';
        }

        foreach ( @watchers ) {
            my ($fh, $ws) = @$_;
            foreach my $watcher ( @$ws ) {
                try { $watcher->callback->( $fh ) }
                catch ($e) {
                    confess "Error occurred while running Watcher callback: $e"
                }
            }
        }

    }

    ## ------------------------------------------------------------------------
    ## The main loop
    ## ------------------------------------------------------------------------

    method next_tick ($f) {
        ref $f eq 'CODE' || confess 'The `$f` arg must be a CODE ref';

        $logger->log_from( $init_ref, DEBUG, "Adding callback for next-tick >> caller: ".(caller(2))[3] ) if DEBUG;

        push @callbacks => $f;
        return;
    }

    method run_init {
        $init_ref = $self->spawn( Stella::ActorProps->new( class => 'Stella::Actor' ) );

        $logger->log_from( $init_ref, DEBUG, "Running init callback ...") if DEBUG;

        try { $init->( Stella::Core::Context->new( actor_ref => $init_ref, system => $self ) ) }
        catch ($e) {
            confess "Error occurred while running init callback: $e"
        }
    }

    method exit_loop {
        $logger->log_from( $init_ref, DEBUG, "Exiting loop ...") if DEBUG;
        $self->despawn($init_ref, 1);
        $logger->log_from( $init_ref, DEBUG, "Exited loop") if DEBUG;
    }


    method loop {

        my $now = $self->now;

        $logger->line("init") if INFO;
        $self->run_init;

        $logger->line("start") if INFO;

        # TODO: move this while condition into method
        # so that we can add the LOOP_FOREVER feature
        while ( @timers || @callbacks || $mailbox->has_messages ) {
            $tick++;
            $logger->line(sprintf "tick(%03d)" => $tick) if INFO;
            $self->tick;

            my $wait = 0;

            if ( !$mailbox->has_messages && @timers ) {
                if (my $next_timer = $self->get_next_timer) {
                    $wait = $next_timer->[0] - $time;
                }
            }

            # do not wait for negative values ...
            if ($wait < $Stella::Core::Timer::TIMER_PRECISION_DECIMAL) {
                $wait = 0;
            }

            $logger->line( sprintf 'wait(%f)' => $wait ) if INFO && $wait;

            $self->check_watchers( $wait );
        }
        $logger->line("end") if INFO;

        $self->exit_loop;
        $logger->line("exited") if INFO;

        return;
    }

    ## ------------------------------------------------------------------------
    ## Statistics
    ## ------------------------------------------------------------------------

    method statistics {
        # TODO:
        # Make this into a hash which exists for the
        # lifetime of the system and collects stats
        # and then it can add these things at the
        # end.
        +{
            dead_letter_queue => [ $mailbox->dump_dead_letters ],
            zombies           => [ keys %actor_refs   ],
            watchers          => {
                # TODO - improve this
                r => +{
                    map {
                        $_ => $watchers{r}->{$_}
                    } keys $watchers{r}->%*
                },
                w => +{
                    map {
                        $_ => $watchers{w}->{$_}
                    } keys $watchers{w}->%*
                },
            },
        }
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::ActorSystem

=head1 DESCRIPTION

The L<Stella::ActorSystem> does a number of things:

=over 1

=item it manages L<Stella::ActorRef> instances of spawned L<Stella::Actors>

=item it handles the L<Stella::Core::Message> delivery queue

=item it manages the loop within which the L<Stella::Actor> instances live

=back

=cut
