
use v5.38;
use experimental 'class', 'try';

class Stella::ActorSystem {
    use Time::HiRes 'sleep';
    use Carp        'confess';

    use Stella::Util::Debug;

    my $PIDS = 0;

    field %actor_refs;
    field @deferred;
    field @msg_queue;
    field @dead_letter_queue;

    field $init :param;

    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method spawn ($actor) {
        $actor isa Stella::Actor || confess 'The `$actor` arg must be an Actor';

        my $a = Stella::ActorRef->new( pid => ++$PIDS, system => $self, actor => $actor );
        $actor_refs{ $a->pid } = $a;
        $a;
    }

    method despawn ($actor_ref) {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` arg must be an ActorRef';

        push @deferred => sub {
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

        try { (shift @deferred)->() while @deferred }
        catch ($e) {
            confess "Error occurred while running deferred($phase) callbacks: $e";
        }
    }

    method run_init {
        my $init_ctx = $self->spawn( Stella::Actor->new );

        try { $init->( $init_ctx ) }
        catch ($e) {
            confess "Error occurred while running init callback: $e"
        }

        $self->despawn($init_ctx);
    }

    method tick {
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
                $self->add_to_dead_letter( ACTOR_NOT_FOUND => $msg );
            }
        }
    }

    method loop ($delay=undef) {
        my $tick = 0;

        $logger->line("init") if INFO;
        $self->run_init;

        $logger->line("start") if INFO;
        while (1) {
            $tick++;
            $logger->line(sprintf "tick(%03d)" => $tick) if INFO;
            $self->tick;

            $self->run_deferred('idle');
            last unless @msg_queue;

            sleep($delay) if defined $delay;
        }
        $logger->line("end") if INFO;

        $self->run_deferred('cleanup');
        $logger->line("exited") if INFO;

        return;
    }

    # Debugger routines

    method DeadLetterQueue { @dead_letter_queue }
    method ActiveActorRefs { keys %actor_refs   }
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
