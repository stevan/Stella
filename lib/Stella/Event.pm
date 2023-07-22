
use v5.38;
use experimental 'class';

class Stella::Event {
    use Carp 'confess';

    field $symbol  :param;
    field $payload :param = [];

    ADJUST {
        defined $symbol         || confess 'The `symbol` param must be a defined value';
        ref $payload eq 'ARRAY' || confess 'The `payload` param must be an ARRAY ref';
    }

    method symbol  { $symbol  }
    method payload { $payload }
}

__END__

# -----------------------------------------------------------------------------
# Event
# -----------------------------------------------------------------------------
# An Event can thought of as a deffered method call. The `$symbol` being the
# name of the method, and the $payload being the an ARRAY ref of arguments to
# the method.
#
# An Event is the primary payload of the Message object.
# -----------------------------------------------------------------------------
