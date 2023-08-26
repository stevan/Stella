
use v5.38;
use experimental 'class';

class Stella::Streams::Sink {
    use constant DROP  => \'DROP';
    use constant DONE  => \'DONE';
    use constant DRAIN => \'DRAIN';

    method drip;
    method done;
    method drain;
}

class Stella::Streams::Sink::ToCallback :isa(Stella::Streams::Sink) {
    use Stella::Tools::Functions 'confess';

    field $callback :param;

    ADJUST {
        ref $callback eq 'CODE' || confess 'The `$callback` param must be a CODE ref';
    }

    method drip ($drop) { $callback->( $drop, $self->DROP  ) }
    method done         { $callback->( undef, $self->DONE  ) }
    method drain        { $callback->( undef, $self->DRAIN ) }
}

class Stella::Streams::Sink::ToBuffer :isa(Stella::Streams::Sink) {
    field @buffer;

    method drip ($drop) {
        return if @buffer
               && $buffer[-1] == $self->DONE;
        push @buffer => $drop;
    }

    method done { push @buffer => $self->DONE }

    method drain {
        my @sink = @buffer;
        @buffer = ();
        pop @sink if $sink[-1] == $self->DONE;
        @sink;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Sink

=head1 DESCRIPTION

=cut
