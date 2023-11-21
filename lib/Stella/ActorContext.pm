
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

use Stella::Core::Message;

use Stella::Core::Timer; # loads Interval
use Stella::Core::Watcher;

use Stella::Core::Promise;

class Stella::ActorContext {
    use Carp 'confess';

    use overload (
        fallback => 1,
        '""' => \&to_string,
    );

    field $actor_ref :param;

    ADJUST {
        $actor_ref isa Stella::ActorRef || confess 'The `$actor_ref` param must be an ActorRef';
    }

    method pid       { $actor_ref->pid    }
    method system    { $actor_ref->system }
    method actor     { $actor_ref->actor  }
    method actor_ref { $actor_ref }

    method to_string {
        $actor_ref->to_string;
    }

    method promise { Stella::Core::Promise->new( system => $actor_ref->system ) }

    method next_tick ($f) { $actor_ref->system->next_tick( $f ) }

    method add_watcher (%args) {
        my $w = Stella::Core::Watcher->new( %args );
        $actor_ref->system->add_watcher( $w );
        $w;
    }

    method remove_watcher ($watcher) { $actor_ref->system->remove_watcher($watcher) }

    method add_timer (%args) {
        my $timer = Stella::Core::Timer->new( %args );
        $actor_ref->system->schedule_timer( $timer );
        return $timer;
    }

    method add_interval (%args) {
        my $timer = Stella::Core::Timer::Interval->new( %args );
        $actor_ref->system->schedule_timer( $timer );
        return $timer;
    }

    method spawn ($actor) {
        $actor isa Stella::Actor || confess 'The `$actor` arg must be an Actor';

        $actor_ref->system->spawn( $actor );
    }

    method send ($to, $event) {
        $to    isa Stella::ActorRef || confess 'The `$to` arg must be an ActorRef';
        $event isa Stella::Event    || confess 'The `$event` arg must be an Event';

        $actor_ref->system->enqueue_message(
            Stella::Core::Message->new( to => $to, from => $actor_ref, event => $event )
        );
    }

    method exit { $actor_ref->system->despawn( $actor_ref ) }

    method kill ($to_kill) {
        $to_kill isa Stella::ActorRef || confess 'The `$to_kill` arg must be an ActorRef';

        $actor_ref->system->despawn( $to_kill );
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::ActorContext

=head1 DESCRIPTION

The L<Stella::ActorContext> is a wrapper around the L<Stella::Actor> and the
L<Stella::ActorSystem> that provides a number of convenience methods. It is
most often used as a "context" variable that is passed to dispatched methods.

L<Stella::ActorContext> can also be seen as an "activation record" of the
L<Stella::Actor> within the L<Stella::ActorSystem>, as it is the keeper of
the PID value.

=cut
