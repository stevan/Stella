
use v5.38;
use experimental 'class';

use Stella::Message;

class Stella::ActorRef {
    use Carp 'confess';

    field $pid    :param;
    field $system :param;
    field $actor  :param;

    field $behavior;

    ADJUST {
        defined $pid                    || confess 'The `$pid` param must defined value';
        $system isa Stella::ActorSystem || confess 'The `$system` param must be an ActorSystem';
        $actor  isa Stella::Actor       || confess 'The `$actor` param must be an Actor';

        $behavior = $actor->behavior;
    }

    method pid    { $pid    }
    method system { $system }
    method actor  { $actor  }

    method apply ($message) {
        $message isa Stella::Message  || confess 'The `$message` arg must be a Message';

        $behavior->apply( $self, $message );
    }

    method add_timer (%args) {
        my $timer = Stella::Timer->new( %args );
        $system->schedule_timer( $timer );
        return $timer;
    }

    method spawn ($actor) {
        $actor isa Stella::Actor || confess 'The `$actor` arg must be an Actor';

        $system->spawn( $actor );
    }

    method send ($to, $event) {
        $to    isa Stella::ActorRef || confess 'The `$to` arg must be an ActorRef';
        $event isa Stella::Event    || confess 'The `$event` arg must be an Event';

        $system->enqueue_message(
            Stella::Message->new( to => $to, from => $self, event => $event )
        );
    }

    method exit { $system->despawn( $self ) }

    method kill ($actor_ref) {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` arg must be an ActorRef';

        $system->despawn( $actor_ref );
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::ActorRef

=head1 DESCRIPTION

The L<Stella::ActorRef> is a wrapper around the L<Stella::Actor> and the
L<Stella::ActorSystem> that provides a number of convenience methods. It is
most often used as a "context" variable that is passed to dispatched methods.

L<Stella::ActorRef> can also be seen as an "activation record" of the
L<Stella::Actor> within the L<Stella::ActorSystem>, as it is the keeper of
the PID value.

=cut
