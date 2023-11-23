
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::Core::PostOffice {
    use Carp 'confess';

    field $input  :param = undef; # IO::Handle
    field $output :param = undef; # IO::Handle

    field $inbox_watcher;
    field $outbox_watcher;

    field @outgoing;

    my $JSON = JSON->new->utf8;
    my sub encode ($data) { $JSON->encode($data) }
    my sub decode ($json) { $JSON->decode($json) }

    # NOTE: this will be called from RemoveActorRef::apply
    method post_message ($message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        push @outgoing => $message;
    }

    method setup ($system) {
        return unless $input && $output;

        $system isa Stella::ActorSystem || confess 'The `$system` arg must be an ActorSystem';

        $inbox_watcher = $system->add_watcher(
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

                my $data = decode($json);

                # - Inflate $data->{to} to local ActorRef

                $data->{to} = $system->lookup_actor(
                    sprintf '%03d:%s@%s' =>
                        $data->{to}->{pid},
                        $data->{to}->{actor},
                        $data->{to}->{address}
                );

                #  - if ActorRef not found, send to dead_letters
                if (!$data->{to}) {
                    push @dead_letters => [ 'ACTOR NOT FOUND' => $data ];
                }
                else {
                    # TODO
                    # - Inflate $data->{from} to RemoteActorRef
                    # - Inflate any RemoteActorRefs in $data->{event}
                    my $message = Stella::Core::Message->new( $data );
                    $system->enqueue_message($message);
                }

            }
        );

        $outbox_watcher = $system->add_watcher(
            fh       => $output,
            poll     => 'w',
            callback => sub ($fh) {

                my @json;
                foreach my $message (@outgoing) {
                    my $data = {
                        to => {
                            pid     => $to->pid,
                            actor   => blessed $to->actor,
                            address => $to->address,
                        },
                        from => {
                            pid     => $from->pid,
                            actor   => blessed $from->actor,
                            address => $from->address, # TODO: covert this from local to hostname
                        },
                        event => {
                            symbol  => $event->symbol,
                            payload => $event->payload # TODO: default all ActorRefs inside
                        }

                    };
                    # - Deflate $data->{to} ActorRef
                    # - Deflate $data->{from} ActorRef
                    # - Deflate any ActorRefs in $data->{event}
                    my $json = encode($data);
                    push @json => $json;
                }

                $fh->print( join "\n" => @json );

                @outgoing = ();
            }
        );
    }

    method teardown ($system) {
        $system->remove_watcher($inbox_watcher);
        $system->remove_watcher($outbox_watcher);
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Core::PostOffice

=head1 DESCRIPTION

=cut

