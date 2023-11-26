
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::Core::Message {
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

    method pack {
        +{ to => $to->pack, from => $from->pack, event => $event->pack };
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Core::Message

=head1 DESCRIPTION

A L<Stella::Core::Message> is a container for an L<Stella::Event>, which has a sender
(C<$from>) and a recipient (C<$to>), both of which are L<Stella::ActorRef>
instances.

The L<Stella::Core::Message> is the primary means of communication between actors,
with messages being passed via the L<Stella::ActorSystem>

=cut

