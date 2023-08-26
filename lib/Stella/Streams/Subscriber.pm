
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Sink;
use Stella::Streams::Subscription;

class Stella::Streams::Subscriber :isa(Stella::Actor) {
    use Stella::Tools::Debug;
    use Stella::Tools::Functions;

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
        $logger->log_from( $ctx, INFO, '*OnSubscribe called with Subscription('.$s->pid.')' ) if INFO;

        # TODO:
        # check the type of $s here and throw an OnError
        # (or better yet, make typed events)

        $subscription = $s;
        $ctx->send( $subscription, event *Stella::Streams::Subscription::Request, $request_size );
    }

    method OnUnsubscribe ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnUnsubscribe called' ) if INFO;
        $ctx->exit;
    }

    method OnComplete ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnComplete called' ) if INFO;
        $sink->done;
        $ctx->send( $subscription, event *Stella::Streams::Subscription::Cancel );
    }

    method OnRequestComplete ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnRequestComplete called' ) if INFO;
        $ctx->send( $subscription, event *Stella::Streams::Subscription::Request, $request_size );
    }

    method OnNext ($ctx, $message) {
        my ($value) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*OnNext called with value('.$value.')' ) if INFO;
        $sink->drip( $value );
    }

    method OnError ($ctx, $message) {
        my ($error) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*OnError called with error('.$error.')' ) if INFO;
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
