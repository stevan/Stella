#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Streams';
use ok 'Stella::Util::Debug';

use Data::Dumper;

my $LOGGER;
   $LOGGER = Stella::Util::Debug->logger if LOG_LEVEL;

my $MAX_ITEMS = 20;

my $Source = Stella::Streams::Source::FromGenerator->new(
    generator => sub {
        state $count = 0;
        return $count if ++$count <= $MAX_ITEMS;
        return;
    }
);

my @Sinks = (
    Stella::Streams::Sink::ToBuffer->new,
    Stella::Streams::Sink::ToBuffer->new,
    Stella::Streams::Sink::ToCallback->new(
        callback => sub ($item, $marker) {
            state @sink;
            state $done;

            if ($marker == Stella::Streams::Sink->DROP) {
                push @sink => $item unless $done;
            }
            elsif ($marker == Stella::Streams::Sink->DONE) {
                $done++;
            }
            elsif ($marker == Stella::Streams::Sink->DRAIN) {
                my @d = @sink;
                @sink = ();
                $done--;
                @d;
            }
            else {
                die "Unrecognized marker($marker)";
            }
        }
    )
);

# ...

sub init ($ctx) {

    my $publisher = $ctx->spawn(
        Stella::Streams::Publisher->new( source => $Source )
    );


    my $subscriber = $ctx->spawn(
        Stella::Streams::Subscriber->new(
            request_size => 5,
            sink         => $Sinks[0]
        )
    );

    $ctx->send(
        $publisher,
        Stella::Event->new(
            symbol  => *Stella::Streams::Publisher::Subscribe,
            payload => [ $subscriber ]
        )
    );

#    my @subscribers = (
#        $this->spawn( Subscriber( 5,  $Sinks[0] ) ),
#        $this->spawn( Subscriber( 10, $Sinks[1] ) ),
#        $this->spawn( Subscriber( 2,  $Sinks[2] ) ),
#    );
#
#    # trap exits for all
#    $_->trap( *SIGEXIT )
#        foreach ($this, $publisher, @subscribers);
#
#    # link this to the publisher
#    $this->link( $publisher );
#    # and the publisher to the subsribers
#    $publisher->link( $_ ) foreach @subscribers;
#
#
#    $this->send( $publisher, [ *Subscribe => $_ ]) foreach @subscribers;

    $LOGGER->log_from( $ctx, INFO, '... starting' ) if INFO;
}

my $loop = Stella::ActorSystem->new( init => \&init );
isa_ok($loop, 'Stella::ActorSystem');

$loop->loop;

my $stats = $loop->statistics;

eq_or_diff($stats->{dead_letter_queue},[],'... the DeadLetterQueue is empty');
eq_or_diff($stats->{zombies},[],'... there are no Zombie actors');

done_testing();

1;

__END__
