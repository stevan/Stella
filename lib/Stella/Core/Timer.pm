
use v5.38;
use experimental 'class';

class Stella::Core::Timer {
    use Carp 'confess';

    our $TIMER_PRECISION_DECIMAL = 0.001;
    our $TIMER_PRECISION_INT     = 1000;

    field $timeout  :param;
    field $callback :param;

    field $cancelled = 0;

    ADJUST {
        $timeout >= 0           || confess 'The `timeout` param must be a positive number';
        ref $callback eq 'CODE' || confess 'The `callback` param must be an CODE ref';
    }

    method timeout  { $timeout  }
    method callback { $callback }

    method cancel    { $cancelled++ }
    method cancelled { $cancelled   }

    method calculate_end_time ($now) {
        my $end_time = $now + $timeout;
           $end_time = int($end_time * $TIMER_PRECISION_INT) * $TIMER_PRECISION_DECIMAL;

        return $end_time;
    }
}

class Stella::Core::Timer::Interval :isa(Stella::Core::Timer) {}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Core::Timer

=head1 DESCRIPTION

=cut
