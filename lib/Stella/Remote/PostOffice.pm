
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::Remote::PostOffice :isa(Stella::Actor) {
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
                    my $data = {};
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

A PostOffice is an Actor that can be enabled in a given ActorSystem and will watch
an input and output file handle upon which it will send/recieve messages from other
systems.

This is the foundation of the remoting capabilities of Stella.

=head2 SYSTEM TOPOGRAPHY

PostOffice reads from a single input and writes to a single output, this seems limiting
but this enables the following:

=over 4

=item 1-to-1 Communication

Basically this is just a bi-directional pipe between two systems. They can send and
recieve messages between each other because no routing is required.

=item Pipelines (A -to- B -to- C)

This is similar to piping applications in the unix shell. The output of one system
becomes the input of another system, and so on. This is a more restrictive system
as any given segment of the pipeline can only get messages from the previous system
and send them to the next system.

=item Many-to-Many Communicatons

To enable many-to-many communications, there needs to be some kind of routing in place.
The design of this system is such that individual PostOffices will write to a single
output, which in this case would be the router. The router would then forward the
message onto the input for the approproate system.

TODO: Write a Router for this.

=back

=cut

