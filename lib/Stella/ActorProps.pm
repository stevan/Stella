
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::ActorProps {
    use Carp 'confess';

    use overload (
        fallback => 1,
        '""' => \&to_string,
    );

    field $class     :param = undef;
    field $args      :param = undef;
    field $singleton :param = undef;

    ADJUST {
        if ($singleton) {
            $singleton isa Stella::Actor || confess 'The `singleton` must be an instance of Actor';
            !$class && !$args            || confess 'You cannot set `class` or `args` if you set `singleton`';

            $args  = {};
            $class = blessed $singleton;
        } else {
            $args //= {};

            ref $args eq 'HASH'          || confess 'The `args` param must be a HASH ref';
            $class->isa('Stella::Actor') || confess 'The `class` must be a subclass of Actor';
        }
    }

    method class { $class }
    method args  { $args }

    method new_actor { $singleton // $class->new( %$args ) }

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

