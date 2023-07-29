
use v5.38;
use experimental 'class';

class Stella::Behavior::Method :isa(Stella::Behavior) {
    use Carp 'confess';

    field $allowed :param;

    field %_method_cache;

    ADJUST {
        $_method_cache{$_} = undef foreach @$allowed;
    }

    method apply ($ctx, $message) {
        $ctx     isa Stella::ActorRef || confess 'The `$ctx` arg must be an ActorRef';
        $message isa Stella::Message  || confess 'The `$message` arg must be a Message';

        my $symbol = $message->event->symbol;
        my $actor  = $ctx->actor;

        exists $_method_cache{ $symbol } || confess "Unsupported message ($symbol)";

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
