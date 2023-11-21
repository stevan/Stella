
use v5.38;
use experimental 'class';

use Stella;

class Stella::Actor::System :isa(Stella::Actor) {
    use Stella::Tools qw[ :events :debug ];

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Spawn ($ctx, $message) {
        my ($actor_class, $response_event) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Spawn called with Actor('.$actor_class.') with Event('.$response_event.') for response' ) if INFO;

        my $actor_ref = $ctx->spawn( $actor_class->new );

        $ctx->send( $message->from, event $response_event => $actor_ref );
    }

    method Kill ($ctx, $message) {
        my ($actor_ref) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Kill called with ActorRef('.$actor_ref.')' ) if INFO;

        $ctx->kill( $actor_ref );
    }

    method Send ($ctx, $message) {
        my ($to, $from, $event) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Send called with To('.$to.')'.
                                       ' From('.$from.')'.
                                       ' Event('.$event.')' ) if INFO;

        $ctx->system->enqueue_message(
            Stella::Core::Message->new( to => $to, from => $from, event => $event )
        );
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Spawn, *Kill, *Send ] );
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Actor::System

=head1 DESCRIPTION


=cut
