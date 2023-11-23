
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::ActorProps {
    use Carp 'confess';

    use overload (
        fallback => 1,
        '""' => \&to_string,
    );

    field $class :param;
    field $args  :param = {};

    ADJUST {
        ref $args eq 'HASH' || confess 'The `args` param must be a HASH ref';
    }

    method class { $class }
    method args  { $args }

    method new_actor { $class->new( %$args ) }

    method to_string {
        sprintf 'Props(%s, %s)' => $class, join ', ' => map { $_ => $args->{$_} } sort keys %$args;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::ActorProps

=head1 DESCRIPTION

=cut

