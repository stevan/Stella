
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

use Stella::Core::Message;
use Stella::ActorContext;

use Stella::Core::Timer; # loads Interval
use Stella::Core::Watcher;

use Stella::Core::Promise;

class Stella::ActorRef {
    use Carp 'confess';

    use overload (
        fallback => 1,
        '""' => \&to_string,
    );

    field $pid     :param;
    field $actor   :param;
    field $address :param = 'local';

    field $behavior;

    ADJUST {
        defined $pid              || confess 'The `$pid` param must defined value';
        $actor  isa Stella::Actor || confess 'The `$actor` param must be an Actor';

        $behavior = $actor->behavior;
    }

    method address { $address }
    method pid     { $pid     }
    method actor   { $actor   }

    method to_string {
        sprintf '%03d:%s@%s' => $pid, blessed $actor, $address;
    }

    method apply ($ctx, $message) {
        $ctx     isa Stella::ActorContext  || confess 'The `$ctx` arg must be a ActorContext';
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        $behavior->apply(
            $ctx,
            $message
        );
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
