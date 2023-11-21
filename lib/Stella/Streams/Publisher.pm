
use v5.38;
use experimental 'class', 'try';

use Stella;
use Stella::Streams::Source;
use Stella::Streams::Subscription;
use Stella::Streams::Subscriber;
use Stella::Streams::Observer::Subscription;

class Stella::Streams::Publisher :isa(Stella::Actor) {
    use Carp 'confess';

    use Stella::Tools qw[ :core :events :debug ];

    field $source :param;

    field @subscriptions;

    field $logger;

    ADJUST {
        $source isa Stella::Streams::Source
            || confess 'The `$source` param must an instance of Stella::Streams::Source';

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Subscribe ($ctx, $message) {
        my ($subscriber) = $message->event->payload->@*;

        # TODO:
        # type check $subscriber here and send
        # an OnError accordingly

        $logger->log_from( $ctx, INFO, '*Subscribe called with Subscriber('.$subscriber.')' ) if INFO;

        my $subscription = $ctx->spawn(
            Stella::Streams::Subscription->new(
                publisher  => $ctx->actor_ref,
                subscriber => $subscriber
            )
        );
        #$subscriber->trap( *SIGEXIT );

        push @subscriptions => $subscription;
        $ctx->send( $subscriber, event *Stella::Streams::Subscriber::OnSubscribe, $subscription );
    }

    method Unsubscribe ($ctx, $message) {
        my ($subscription) = $message->event->payload->@*;

        # TODO:
        # type check $subscription here and send
        # an OnError accordingly

        $logger->log_from( $ctx, INFO, '*Unsubscribe called with Subscription('.$subscription.')' ) if INFO;

        @subscriptions = grep $_ ne $subscription, @subscriptions;

        $ctx->send( $subscription, event *Stella::Streams::Subscription::OnUnsubscribe );

        if (scalar @subscriptions == 0) {
            $logger->log_from( $ctx, INFO, '*Unsubscribe called and no more subscrptions, exiting') if INFO;
            # TODO: this should be more graceful, sending
            # a shutdown message or something, **shrug**
            $ctx->exit;
        }
    }

    method GetNext ($ctx, $message) {
        my ($observer) = $message->event->payload->@*;

        # TODO:
        # type check $observer here and send
        # an OnError accordingly

        $logger->log_from( $ctx, INFO, '*GetNext called with Observer('.$observer.')' ) if INFO;

        my $next;
        try {
            $next = $source->get_next;
        } catch ($e) {
            $ctx->send( $observer, event *Stella::Streams::Observer::OnError, $e );
            # ???
            #return;
        }

        if ( $next ) {
            $logger->log_from( $ctx, INFO, '... *GetNext sending next('.$next.')') if INFO;
            $ctx->send( $observer, event *Stella::Streams::Observer::OnNext, $next );
        }
        else {
            $ctx->send( $observer, event *Stella::Streams::Observer::OnComplete );
        }
    }

    method behavior {
        Stella::Behavior::Method->new(
            allowed => [
                *Subscribe,
                *Unsubscribe,
                *GetNext,
            ]
        );
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Publisher

=head1 DESCRIPTION

=cut
