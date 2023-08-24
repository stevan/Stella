
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Observer;
use Stella::Streams::Publisher;
use Stella::Streams::Subscriber;

class Stella::Streams::Subscription :isa(Stella::Actor) {
    use Stella::Util::Debug;

    use Carp 'confess';

    field $publisher  :param;
    field $subscriber :param;

    field $observer;

    field $logger;

    ADJUST {
        $publisher isa Stella::ActorRef && $publisher->actor isa Stella::Streams::Publisher
            || confess 'The `$publisher` param must an instance of Stella::Streams::Publisher not '.$publisher;
        $subscriber isa Stella::ActorRef && $subscriber->actor isa Stella::Streams::Subscriber
            || confess 'The `$subscriber` param must an instance of Stella::Streams::Subscriber not '.$subscriber;

        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method Request ($ctx, $message) {
        my ($num_elements) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Request called with ('.$num_elements.')' ) if INFO;

        if ( $observer ) {
            $logger->log_from( $ctx, INFO, '*Request called, killing old observer ('.$observer->pid.')' ) if INFO;
            $ctx->kill( $observer );
        }

        $observer = $ctx->spawn(
            Stella::Streams::Observer->new(
                num_elements => $num_elements,
                subscriber   => $subscriber
            )
        );
        #$observer->trap( *SIGEXIT );

        while ($num_elements--) {
            $ctx->send(
                $publisher,
                Stella::Event->new(
                    symbol  => *Stella::Streams::Publisher::GetNext,
                    payload => [ $observer ]
                )
            );
        }
    }

    method Cancel ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*Cancel called' ) if INFO;
        $ctx->send(
            $publisher,
            Stella::Event->new(
                symbol  => *Stella::Streams::Publisher::Unsubscribe,
                payload => [ $ctx ]
            )
        );
    }

    method OnUnsubscribe ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnUnsubscribe called' ) if INFO;
        $ctx->send(
            $subscriber,
            Stella::Event->new(
                symbol  => *Stella::Streams::Subscriber::OnUnsubscribe
            )
        );
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
