
use v5.38;
use experimental 'class';

class Stella::Message {
    use Carp 'confess';

    field $to    :param;
    field $from  :param;
    field $event :param;

    ADJUST {
        $to    isa Stella::ActorRef || confess 'The `to` param must be an ActorRef';
        $from  isa Stella::ActorRef || confess 'The `from` param must be an ActorRef';
        $event isa Stella::Event    || confess 'The `event` param must be an Event';
    }

    method to    { $to    }
    method from  { $from  }
    method event { $event }
}

__END__

# -----------------------------------------------------------------------------
# Message
# -----------------------------------------------------------------------------
# A Message is a container for an Event, which has a sender (`$from`) and a
# recipient (`$to`), both of which are ActorRef instances.
#
# The Message is the primary means of communication between actors, with
# messages being passed via the ActorSystem.
# -----------------------------------------------------------------------------
