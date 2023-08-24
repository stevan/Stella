
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Subscriber;

class Stella::Streams::Observer :isa(Stella::Actor) {
    use Stella::Util::Debug;

    use Carp 'confess';

    field $num_elements :param;
    field $subscriber   :param;

    field $seen = 0;
    field $done = 0;

    field $logger;

    ADJUST {
        $num_elements > 0 || confess 'The `$num_elements` param must be greater than 0';

        $subscriber isa Stella::ActorRef && $subscriber->actor isa Stella::Streams::Subscriber
            || confess 'The `$subscriber` param must an instance of Stella::Streams::Subscriber';

        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method OnComplete ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnComplete observed' ) if INFO;

        if (!$done) {
            $logger->log_from( $ctx, INFO, '*OnComplete circuit breaker tripped' ) if INFO;
            $done = 1;
        }

        $seen++;
        if ( $num_elements <= $seen ) {
            $logger->log_from( $ctx, INFO,
                '*OnComplete observed seen('.$seen.') '
                .'of ('.$num_elements.') '
                .'sending *OnComplete to ('.$subscriber->pid.')'
            ) if INFO;

            $ctx->send(
                $subscriber,
                Stella::Event->new(
                    symbol => *Stella::Streams::Subscriber::OnComplete
                )
            );
            $seen = 0;
        }
    }

    method OnNext ($ctx, $message) {
        my ($value) = $message->event->payload->@*;

        $logger->log_from( $ctx, INFO, '*OnNext observed with ('.$value.')' ) if INFO;

        $ctx->send(
            $subscriber,
            Stella::Event->new(
                symbol  => *Stella::Streams::Subscriber::OnNext,
                payload => [ $value ]
            )
        );

        $seen++;
        if ( $num_elements <= $seen ) {
            $logger->log_from( $ctx, INFO,
                '*OnNext observed seen('.$seen.') '
                .'of ('.$num_elements.') '
                .'sending *OnRequestComplete to ('.$subscriber->pid.')'
            ) if INFO;

            $ctx->send(
                $subscriber,
                Stella::Event->new(
                    symbol => *Stella::Streams::Subscriber::OnRequestComplete
                )
            );
            $seen = 0;
            $done = 1;
        }
    }

    method OnError ($ctx, $message) {
        my ($error) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*OnError observed with ('.$error.')' ) if INFO;
        $ctx->send(
            $subscriber,
            Stella::Event->new(
                symbol  => *Stella::Streams::Subscriber::OnError,
                payload => [ $error ]
            )
        );
    }

    method behavior {
        Stella::Behavior::Method->new(
            allowed => [
                *OnNext,
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

Stella::Streams::Observer

=head1 DESCRIPTION

=cut
