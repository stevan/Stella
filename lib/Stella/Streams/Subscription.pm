
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Observer::Subscription;
use Stella::Streams::Publisher;
use Stella::Streams::Subscriber;

class Stella::Streams::Subscription :isa(Stella::Actor) {
    use Carp 'confess';

    use Stella::Tools qw[ :core :events :debug ];

    field $publisher  :param;
    field $subscriber :param;

    field $observer;

    field $logger;

    ADJUST {
        actor_isa( $publisher, 'Stella::Streams::Publisher' )
            || confess 'The `$publisher` param must an instance of Stella::Streams::Publisher not '.$publisher;
        actor_isa( $subscriber, 'Stella::Streams::Subscriber' )
            || confess 'The `$subscriber` param must an instance of Stella::Streams::Subscriber not '.$subscriber;

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Request ($ctx, $message) {
        my ($num_elements) = $message->event->payload->@*;
        $logger->log( INFO, '*Request called with num_elements('.$num_elements.')' ) if INFO;

        if ( $observer ) {
            $logger->log( INFO, '*Request called, killing old Observer('.$observer.')' ) if INFO;
            $ctx->kill( $observer );
        }

        $observer = $ctx->spawn(
            Stella::ActorProps->new(
                class => 'Stella::Streams::Observer::Subscription',
                args  => {
                    num_elements => $num_elements,
                    subscriber   => $subscriber
                }
            )
        );
        #$observer->trap( *SIGEXIT );

        while ($num_elements--) {
            $publisher->send( event *Stella::Streams::Publisher::GetNext, $observer );
        }
    }

    method Cancel ($ctx, $message) {
        $logger->log( INFO, '*Cancel called' ) if INFO;
        $publisher->send( event *Stella::Streams::Publisher::Unsubscribe, $ctx->self );
    }

    method OnUnsubscribe ($ctx, $message) {
        $logger->log( INFO, '*OnUnsubscribe called' ) if INFO;
        $subscriber->send( event *Stella::Streams::Subscriber::OnUnsubscribe );
        $ctx->kill( $observer );
        $ctx->exit;
    }

    method behavior {
        Stella::Behavior::Method->new(
            allowed => [
                *Request,
                *Cancel,
                *OnUnsubscribe,
            ]
        );
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Subscription

=head1 DESCRIPTION

=cut
