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

my $MAX_ITEMS = 17;

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

    my @subscribers = (
        $ctx->spawn(
            Stella::Streams::Subscriber->new(
                request_size => 5,
                sink         => $Sinks[0]
            )
        ),
        $ctx->spawn(
            Stella::Streams::Subscriber->new(
                request_size => 10,
                sink         => $Sinks[1]
            )
        ),
        $ctx->spawn(
            Stella::Streams::Subscriber->new(
                request_size => 2,
                sink         => $Sinks[2]
            )
        ),
    );

    $ctx->send(
        $publisher,
        Stella::Event->new(
            symbol  => *Stella::Streams::Publisher::Subscribe,
            payload => [ $_ ]
        )
    ) foreach @subscribers;

    $LOGGER->log_from( $ctx, INFO, '... starting' ) if INFO;
}

my $loop = Stella::ActorSystem->new( init => \&init );
isa_ok($loop, 'Stella::ActorSystem');

$loop->loop;

eq_or_diff([ $Sinks[0]->drain ], [ 1 .. 5  ], '... the sinks contrain the right items');
eq_or_diff([ $Sinks[1]->drain ], [ 6 .. 15 ], '... the sinks contrain the right items');
eq_or_diff([ $Sinks[2]->drain ], [ 16, 17  ], '... the sinks contrain the right items');

my $stats = $loop->statistics;

eq_or_diff($stats->{dead_letter_queue},[],'... the DeadLetterQueue is empty');
eq_or_diff($stats->{zombies},[],'... there are no Zombie actors');

done_testing();

1;

__END__
