
use v5.38;
use experimental 'class';

class Stella::Core::Mailbox {
    use Carp 'confess';

    field $input  :param = undef;
    field $output :param = undef;

    field @messages;
    field @outgoing;
    field @dead_letters;

    method setup ($system) {
        return unless $input && $output;

        $system isa Stella::ActorSystem || confess 'The `$system` arg must be an ActorSystem';

        $system->add_watcher(
            fh       => $input,
            poll     => 'r',
            callback => sub ($fh) {
                my $json = $fh->readline; # FIXME: this can block, do better

                # NOTE: this should be in side a loop
                # that keeps reading until it can't anymore
                # but that might not really work here
                # so maybe we just sysread a big chunk
                # and then split on newlines and decode
                # either way, this should be done better

                my $data = {}; # JSON::decode( $json );
                # - Inflate $data->{to} to local ActorRef
                #     - if ActorRef not found, send to dead_letters
                # - Inflate $data->{from} to RemoteActorRef
                # - Inflate any RemoteActorRefs in $data->{event}
                my $message = Stella::Core::Message->new( $data );
                push @messages => $message;
            }
        );

        $system->add_watcher(
            fh       => $output,
            poll     => 'w',
            callback => sub ($fh) {

                my @json;
                foreach my $message (@outgoing) {
                    my $data = {};
                    # - Deflate $data->{to} ActorRef
                    # - Deflate $data->{from} ActorRef
                    # - Deflate any ActorRefs in $data->{event}
                    my $json = "{}"; # JSON::encode($data)
                    push @json => $json;
                }

                $fh->print( join "\n" => @json );

                @outgoing = ();
            }
        );
    }

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

