
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Observer;
use Stella::Streams::Subscriber;

class Stella::Streams::Observer::Subscription :isa(Stella::Streams::Observer) {
    use Carp 'confess';

    use Stella::Tools qw[ :core :events :debug ];

    field $num_elements :param;
    field $subscriber   :param;

    field $seen = 0;
    field $done = 0;

    field $logger;

    ADJUST {
        $num_elements > 0 || confess 'The `$num_elements` param must be greater than 0';

        actor_isa( $subscriber, 'Stella::Streams::Subscriber' )
            || confess 'The `$subscriber` param must an instance of Stella::Streams::Subscriber';

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method on_complete ($ctx, $message) {
        if (!$done) {
            $logger->log( INFO, '*OnComplete circuit breaker tripped' ) if INFO;
            $done = 1;
        }

        $seen++;
        if ( $num_elements <= $seen ) {
            $logger->log( INFO,
                '*OnComplete observed seen('.$seen.') '
                .'of num_elements('.$num_elements.') '
                .'sending *OnComplete to Subscriber('.$subscriber.')'
            ) if INFO;

            $subscriber->send( event *Stella::Streams::Subscriber::OnComplete );
            $seen = 0;
        }
    }

    method on_next ($ctx, $message) {
        my ($value) = $message->event->payload->@*;

        $logger->log( INFO, '*OnNext observed with value('.$value.')' ) if INFO;

        $subscriber->send( event *Stella::Streams::Subscriber::OnNext, $value );

        $seen++;
        if ( $num_elements <= $seen ) {
            $logger->log( INFO,
                '*OnNext observed seen('.$seen.') '
                .'of num_elements('.$num_elements.') '
                .'sending *OnRequestComplete to Subscriber('.$subscriber.')'
            ) if INFO;

            $subscriber->send( event *Stella::Streams::Subscriber::OnRequestComplete );
            $seen = 0;
            $done = 1;
        }
    }

    method on_error ($ctx, $message) {
        my ($error) = $message->event->payload->@*;
        $logger->log( INFO, '*OnError observed with error('.$error.')' ) if INFO;
        $subscriber->send( event *Stella::Streams::Subscriber::OnError, $error );
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Observer::Subscription

=head1 DESCRIPTION

=cut
