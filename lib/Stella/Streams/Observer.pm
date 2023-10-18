use v5.38;
use experimental 'class';

use Stella;

class Stella::Streams::Observer :isa(Stella::Actor) {
    method on_next;
    method on_complete;
    method on_error;

    method OnNext     ($ctx, $message) { $self->on_next($ctx, $message)     }
    method OnComplete ($ctx, $message) { $self->on_complete($ctx, $message) }
    method OnError    ($ctx, $message) { $self->on_error($ctx, $message)    }

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

Stella::Observer

=head1 DESCRIPTION

=cut
