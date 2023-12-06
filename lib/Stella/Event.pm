
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

    method to_string {
        sprintf '%s => (%s)' => $symbol, join ', ' => @$payload;
    }

    method pack {
        +{ symbol => $symbol, payload => [ $payload ] };
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Event

=head1 DESCRIPTION

A L<Stella::Event> can thought of as a deffered method call. The C<$symbol> being
the name of the method, and the C<$payload> being a list of arguments to the method.

An L<Stella::Event> is the primary payload of the L<Stella::Core::Message> object.

=cut
