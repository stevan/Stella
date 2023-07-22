
use v5.38;
use experimental 'class', 'try';

class Stella::ActorSystem {
    use Time::HiRes 'sleep';
    use Carp        'confess';

    my $PIDS = 0;

    field %actor_refs;
    field @deferred;
    field @msg_queue;
    field @dead_letter_queue;

    field $init :param;

    use constant DEBUG => $ENV{DEBUG} // 0;

    my sub LINE ($label) { warn join ' ' => '--', $label, ('-' x (80 - length $label)), "\n" }
    my sub LOG  (@msg)   { warn @msg, "\n" }

    method spawn ($actor) {
        $actor isa Stella::Actor || confess 'The `$actor` arg must be an Actor';

        my $a = Stella::ActorRef->new( pid => ++$PIDS, system => $self, actor => $actor );
        $actor_refs{ $a->pid } = $a;
        $a;
    }

    method despawn ($actor_ref) {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` arg must be an ActorRef';

        push @deferred => sub {
            LOG "Despawning ".$actor_ref->pid if DEBUG;
            delete $actor_refs{ $actor_ref->pid };
        };
    }

    method enqueue_message ($message) {
        $message isa Stella::Message || confess 'The `$message` arg must be a Message';

        push @msg_queue => $message;
    }

    method drain_messages {
        my @msgs   = @msg_queue;
        @msg_queue = ();
        return @msgs;
    }

    method add_to_dead_letter ($reason, $message) {
        push @dead_letter_queue => [ $reason, $message ];
    }


    method run_deferred ($phase) {
        return unless @deferred;
        LOG ">>> deferred[ $phase ]" if DEBUG;
        (shift @deferred)->() while @deferred;
    }

    method exit_loop {
        if (DEBUG) {
            @dead_letter_queue and say "Dead Letter Queue:\n".join "\n" => map { join ', ' => @$_ } @dead_letter_queue;
            %actor_refs        and say "Zombies:\n".join ", " => sort { $a <=> $b } keys %actor_refs;
        }
    }

    method run_init {
        my $init_ctx = $self->spawn( Stella::Actor->new );
        $init->( $init_ctx );
        $self->despawn($init_ctx);
    }

    method tick {
        my @msgs = $self->drain_messages;
        while (@msgs) {
            my $msg = shift @msgs;
            if ( my $actor_ref = $actor_refs{ $msg->to->pid } ) {
                try {
                    $actor_ref->actor->apply( $actor_ref, $msg );
                } catch ($e) {
                    $self->add_to_dead_letter( $e => $msg );
                }
            }
            else {
                $self->add_to_dead_letter( ACTOR_NOT_FOUND => $msg );
            }
        }
    }

    method loop ($delay=undef) {

        LINE "init" if DEBUG;
        $self->run_init;

        LINE "start" if DEBUG;
        while (1) {
            LINE "tick" if DEBUG;
            $self->tick;
            $self->run_deferred('idle');
            last unless @msg_queue;
            sleep($delay) if defined $delay;
        }
        LINE "exiting" if DEBUG;

        $self->run_deferred('cleanup');
        $self->exit_loop;

        LINE "exited" if DEBUG;
        return;
    }

}

__END__

# -----------------------------------------------------------------------------
# ActorSystem
# -----------------------------------------------------------------------------
# The ActorSystem does a number of things:
# - it manages ActorRef instances of spawned Actors
# - it handles the Message delivery queue
# - it manages the loop within which the Actors live
# -----------------------------------------------------------------------------
