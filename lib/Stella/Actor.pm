
use v5.38;
use experimental 'class';

class Stella::Actor {
    use Carp 'confess';

    method apply ($ctx, $message) {
        $ctx     isa Stella::ActorRef || confess 'The `$ctx` arg must be an ActorRef';
        $message isa Stella::Message  || confess 'The `$message` arg must be a Message';

        my $symbol = $message->event->symbol;
        my $method = $self->can($symbol);

        defined $method || confess "Unable to find message for ($symbol)";

        $self->$method( $ctx, $message );
    }
}

__END__

# -----------------------------------------------------------------------------
# Actor
# -----------------------------------------------------------------------------
# The simplest Actor, it will attempt to apply a Message by looking up
# the Message event's symbol. In this case, the Actor will look for a
# method of the same name within it's dispatch table.
#
# Actor is meant to be subclassed and methods added to enable behaviors
# that can be called via an Event.
# -----------------------------------------------------------------------------
