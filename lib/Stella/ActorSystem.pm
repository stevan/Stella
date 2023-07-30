
use v5.38;
use experimental 'class', 'try';

class Stella::ActorSystem {
    use Time::HiRes 'sleep';
    use Carp        'confess';

    use Stella::Util::Debug;

    my $PIDS = 0;

    field %actor_refs;        # PID to ActorRef mapping of active Actors
    field @timers;            # queue of Timer/Interval objects to run
    field @deferred;          # queue used to defer actions until end of loop
    field @msg_queue;         # queue of message to be deliverd to actors
    field @dead_letter_queue; # queue of messages that failed to delivery for a given reason

    field $time = 0; # the current time, using Time::HiRes
    field $tick = 0; # the current tick of the loop

    field $init :param; # function that accepts am ActorRef ($init_ctx) as its only argument
    field $init_ctx;

    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method spawn ($actor) {
        $actor isa Stella::Actor || confess 'The `$actor` arg must be an Actor';

        my $a = Stella::ActorRef->new( pid => ++$PIDS, system => $self, actor => $actor );
        $actor_refs{ $a->pid } = $a;

        $logger->log_from(
            $init_ctx, DEBUG,
            (sprintf "Spawning ACTOR(%s) with PID(%d) and REF(%s)" => "$actor", $a->pid, "$a")
        ) if DEBUG && $init_ctx;

        $a;
    }

    method despawn ($actor_ref) {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` arg must be an ActorRef';

        $logger->log_from(
            $init_ctx, DEBUG,
            (sprintf "Request despawning of REF(%s) with PID(%d)" => "$actor_ref", $actor_ref->pid)
        ) if DEBUG;

        push @deferred => sub {
            $logger->log_from( $init_ctx, DEBUG, "... Despawning REF($actor_ref) PID(".$actor_ref->pid.")") if DEBUG;
            delete $actor_refs{ $actor_ref->pid };
        };
    }

    method enqueue_message ($message) {
        $message isa Stella::Message || confess 'The `$message` arg must be a Message';

        $logger->log_from(
            $init_ctx, DEBUG,
            (sprintf "Enqueue Message to(%s) from(%s) event(%s)" =>
                $message->to->pid,
                $message->from->pid,
                $message->event->symbol,
            )
        ) if DEBUG;

        push @msg_queue => $message;
    }

    method drain_messages {
        my @msgs   = @msg_queue;
        @msg_queue = ();
        return @msgs;
    }

    method add_to_dead_letter ($reason, $message) {
        push @dead_letter_queue => [ $reason, $message ];

        $logger->log_from(
            $init_ctx, ERROR,
            "Adding MSG($message) to Dead Letter Queue because ($reason)"
        ) if ERROR;
    }

    method run_deferred ($phase) {
        return unless @deferred;

        $logger->log_from( $init_ctx, DEBUG, "Running deferred ...") if DEBUG;

        try { (shift @deferred)->() while @deferred }
        catch ($e) {
            confess "Error occurred while running deferred($phase) callbacks: $e";
        }
    }

    method run_init {
        $init_ctx = $self->spawn( Stella::Actor->new );

        $logger->log_from( $init_ctx, DEBUG, "Running init callback ...") if DEBUG;

        try { $init->( $init_ctx ) }
        catch ($e) {
            confess "Error occurred while running init callback: $e"
        }
    }

    method exit_loop {
        $logger->log_from( $init_ctx, DEBUG, "Exiting loop ...") if DEBUG;
        $self->despawn($init_ctx);
        $self->run_deferred('cleanup');
        $logger->log_from( $init_ctx, DEBUG, "Exited loop") if DEBUG;
    }

    # ticks and timers ..

    method now  {
        state $MONOTONIC = Time::HiRes::CLOCK_MONOTONIC();
        # always stay up to date ...
        $time = Time::HiRes::clock_gettime( $MONOTONIC );
    }

    method schedule_timer ($timer) {

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

    method tick {
        # timers ...

        my $now = $self->now;

        if ( @timers ) {
            my @intervals;
            $logger->log_from( $init_ctx, DEBUG, "Got timers ...") if DEBUG;
            while (@timers && $timers[0]->[0] <= $now) {
                $logger->log_from( $init_ctx, DEBUG, "Running timers ($now) ...") if DEBUG;
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
                        if $t isa Stella::Timer::Interval
                        && !$t->cancelled;
                }
            }

            $self->schedule_timer( $_ ) foreach @intervals;
        }

        # messages ...

        if (@msg_queue) {
            my @msgs = $self->drain_messages;
            while (@msgs) {
                my $msg = shift @msgs;
                if ( my $actor_ref = $actor_refs{ $msg->to->pid } ) {
                    try {
                        $actor_ref->apply( $msg );
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

    our $TIMER_PRECISION = 0.001;

    method loop {

        my $now = $self->now;

        $logger->line("init") if INFO;
        $self->run_init;

        $logger->line("start") if INFO;
        while ( @timers || @msg_queue ) {
            $tick++;
            $logger->line(sprintf "tick(%03d)" => $tick) if INFO;
            $self->tick;

            $self->run_deferred('idle');

            # if we have timers, but nothing in
            # the queues, then we can wait
            if ( @timers && !@msg_queue ) {
                my $next_timer = $timers[0];

                if ( $next_timer && $next_timer->[1]->@* ) {
                    my $wait = ($next_timer->[0] - $time);

                    # do not wait for negative values ...
                    if ($wait > $TIMER_PRECISION) {
                        # XXX - should have some kind of max-timeout here
                        $logger->line( sprintf 'wait(%f)' => $wait ) if INFO;
                        sleep( $wait );
                    }
                }
            }
        }
        $logger->line("end") if INFO;

        $self->exit_loop;
        $logger->line("exited") if INFO;

        return;
    }

    # ...

    method statistics {
        +{
            dead_letter_queue => \@dead_letter_queue,
            zombies           => [ keys %actor_refs ],
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

=item it handles the L<Stella::Message> delivery queue

=item it manages the loop within which the L<Stella::Actor> instances live

=back

=cut
