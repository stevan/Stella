
use v5.38;
use experimental 'class';

class Stella::Behavior::Method :isa(Stella::Behavior) {
    use Carp 'confess';

    field $allowed :param;

    field %_method_cache;

    ADJUST {
        $_method_cache{$_} = undef foreach @$allowed;
    }

    method apply ($actor, $ctx, $message) {
        # $actor   isa Stella::Actor
        # $ctx     isa Stella::Core::Context
        # $message isa Stella::Core::Message

        my $symbol = $message->event->symbol;

        exists $_method_cache{ $symbol } || confess "Unsupported message ($symbol)";

        # FIXME:
        # This is not exactly how I want it to work,

        # perl -E 'package Bar { sub foo { "FOO" } }; package Foo { sub bar { "BAR" } }; say Foo->can(*Bar::foo)->()'
        # FOO

        # basically `can` will always return true and will just
        # call the method with the invocant and hope it works.
        #
        # this will most certainly break with class objects as
        # they will not have the same instance pad.

        my $method = $_method_cache{ $symbol } //= $actor->can($symbol);

        $actor->$method( $ctx, $message );

        return;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Behavior::Method

=head1 DESCRIPTION

=cut
