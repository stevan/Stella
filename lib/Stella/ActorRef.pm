
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::ActorRef {
    use Carp 'confess';

    field $pid         :param;
    field $actor_props :param;
    field $address     :param = 'local';

    field $actor;
    field $behavior;
    field $context;

    ADJUST {
        defined $pid                        || confess 'The `$pid` param must defined value';
        defined $address                    || confess 'The `$address` param must defined value';
        $actor_props isa Stella::ActorProps || confess 'The `$actor_props` param must be an ActorProps';
    }

    # ... Lifecycle

    method start ($ctx) {
        $actor    = $actor_props->new_actor;
        $behavior = $actor->behavior;
        $context  = $ctx;
    }

    method stop {
        $actor    = undef;
        $behavior = undef;
        $context  = undef;
    }

    method restart ($ctx) {
        $self->stop;
        $self->start($ctx);
    }

    # ...

    method context { $context }

    method actor_isa ($class) { $actor_props->class->isa( $class ) }

    method to_string {
        sprintf '%03d:%s@%s' => $pid, $actor_props->class, $address;
    }

    method apply ($message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        $actor && $behavior && $context || confess 'Cannot call `apply` before starting the Actor';

        $behavior->apply(
            $actor,
            $context,
            $message
        );
    }

    method pack {
        +{ pid => $pid, actor_class => $actor_props->class, address => $address };
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::ActorRef

=head1 DESCRIPTION

The L<Stella::ActorRef> is a wrapper around the L<Stella::Actor>.

L<Stella::ActorRef> can also be seen as an "activation record" of the
L<Stella::Actor> within the L<Stella::ActorSystem>, as it is the keeper of
the PID value.

=cut
