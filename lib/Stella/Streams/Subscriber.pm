
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Sink;
use Stella::Streams::Subscription;

class Stella::Streams::Subscriber :isa(Stella::Actor) {
    use Carp 'confess';

    use Stella::Tools qw[ :core :events :debug ];

    field $request_size :param;
    field $sink         :param;

    field $subscription;

    field $logger;

    ADJUST {
        $request_size > 0 || confess 'The `$request_size` param must be greater than 0';

        $sink isa Stella::Streams::Sink
            || confess 'The `$sink` param must an instance of Stella::Streams::Sink';

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method OnSubscribe ($ctx, $message) {
        my ($s) = $message->event->payload->@*;
        $logger->log( INFO, '*OnSubscribe called with Subscription('.$s.')' ) if INFO;

        # TODO:
        # check the type of $s here and throw an OnError
        # (or better yet, make typed events)

        $subscription = $s;
        $subscription->send( event *Stella::Streams::Subscription::Request, $request_size );
    }

    method OnUnsubscribe ($ctx, $message) {
        $logger->log( INFO, '*OnUnsubscribe called' ) if INFO;
        $ctx->exit;
    }

    method OnComplete ($ctx, $message) {
        $logger->log( INFO, '*OnComplete called' ) if INFO;
        $sink->done;
        $subscription->send( event *Stella::Streams::Subscription::Cancel );
    }

    method OnRequestComplete ($ctx, $message) {
        $logger->log( INFO, '*OnRequestComplete called' ) if INFO;
        $subscription->send( event *Stella::Streams::Subscription::Request, $request_size );
    }

    method OnNext ($ctx, $message) {
        my ($value) = $message->event->payload->@*;
        $logger->log( INFO, '*OnNext called with value('.$value.')' ) if INFO;
        $sink->drip( $value );
    }

    method OnError ($ctx, $message) {
        my ($error) = $message->event->payload->@*;
        $logger->log( INFO, '*OnError called with error('.$error.')' ) if INFO;
    }

    method behavior {
        Stella::Behavior::Method->new(
            allowed => [
                *OnSubscribe,
                *OnUnsubscribe,
                *OnNext,
                *OnRequestComplete,
                *OnComplete,
                *OnError
            ]
        );
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Subscriber

=head1 DESCRIPTION

=cut
