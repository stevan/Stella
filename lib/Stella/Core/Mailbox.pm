
use v5.38;
use experimental 'class';

class Stella::Core::Mailbox {
    use Carp 'confess';

    field @messages;
    field @dead_letters;

    method has_messages { !! scalar @messages }

    method enqueue_message ($message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';
        push @messages => $message;
    }

    method drain_messages {
        my @msgs  = @messages;
        @messages = ();
        return @msgs;
    }

    method add_dead_letter ($reason, $message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';
        push @dead_letters => [ $reason, $message ];
    }

    method dump_dead_letters {
        my @letters  = @dead_letters;
        @dead_letters = ();
        return @letters;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Core::Mailbox

=head1 DESCRIPTION

=cut

