
use v5.38;
use experimental 'class';

use Stella;
use Stella::Streams::Subscriber;

class Stella::Observer::Callback :isa(Stella::Actor) {
    use Carp 'confess';

    use Stella::Tools qw[ :debug ];

    field $on_next     :param;
    field $on_complete :param;
    field $on_error    :param;

    field $logger;

    ADJUST {
        ref($on_next)     eq 'CODE' || confess 'The `$on_next` must be a CODE ref';
        ref($on_complete) eq 'CODE' || confess 'The `$on_complete` must be a CODE ref';
        ref($on_error)    eq 'CODE' || confess 'The `$on_error` must be a CODE ref';

        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method on_complete ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnComplete observed' ) if INFO;
        $on_complete->($ctx, $message);
    }

    method on_next ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnNext observed' ) if INFO;
        $on_next->($ctx, $message);
    }

    method on_error ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*OnError observed' ) if INFO;
        $on_error->($ctx, $message);
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Observer::Callback

=head1 DESCRIPTION

=cut
