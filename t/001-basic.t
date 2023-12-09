#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools', ':events';

# -----------------------------------------------------------------------------
# PingPong Actor
# -----------------------------------------------------------------------------
# This is an example of a subclasses Actor. It ping/pongs back and forth
# until it reaches it's max, then stops and kills the other.
#
# NOTE:
# I am using GLOBs for the Event symbol, which works out nicely as it will
# warn if we create one that doesn't already exist. They are also already
# namespaced and essentially singletons, so we do not need to manage them.
# -----------------------------------------------------------------------------

class PingPong :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools qw[ :events :debug ];

    field $name :param;  # so I can identify myself in the logs
    field $max  :param;  # the max number of ping/pong(s) to allow

    # counters for ping/pong(s)
    field $pings = 0;
    field $pongs = 0;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Start ($ctx, $message) {
        my ($Other) = $message->event->payload->@*;

        $Other->send( event *Ping );
    }

    method Stop ($ctx, $message) {
        $ctx->exit;
        if ( $ctx->system->is_alive( $message->from ) ) {
            $logger->log( WARN, "... sender is alive, so sending Stop" ) if WARN;
            $message->from->send( event *Stop );
        }
        else {
            $logger->log( WARN, "... sender is not alive, clean exit" ) if WARN;
        }
    }

    method Ping ($ctx, $message) {
        if ($pings < $max) {
            $logger->log( INFO, "...got Ping($name)[$pings] <= $max" ) if INFO;
            $message->from->send( event *Pong );
            $pings++;
        }
        else {
            $logger->log( WARN, "!!! ending Ping at($name)[$pings] <= $max" ) if WARN;
            $message->from->send( event *Stop );
        }
    }

    method Pong ($ctx, $message) {
        if ($pongs < $max) {
            $logger->log( INFO, "... got Pong($name)[$pongs] <= $max" ) if INFO;
            $message->from->send( event *Ping );
            $pongs++;
        }
        else {
            $logger->log( WARN, "!!! ending Pong at($name)[$pongs] <= $max" ) if WARN;
            $message->from->send( event *Stop );
        }
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Start, *Stop, *Ping, *Pong ] );
    }
}

# -----------------------------------------------------------------------------
# `init` function
# -----------------------------------------------------------------------------
# This function is called before the ActorSystem loop starts and it used to
# get the ActorSystem started. The function gets an ActorRef instance as
# context, which can be used to spawn Actors and send Messages.
#
# NOTE:
# This ActorRef actually wraps a plain Actor instance with no methods beyond
# `apply`, so sending messages to it is not useful. This ActorRef will also
# be immediately despawned after the `init` function finishes, so it will not
# be alive long enough to get messages either.
# -----------------------------------------------------------------------------

sub init ($ctx) {
    foreach ( 1 .. 10 ) {
        my $max = int(rand(10));

        my $PongActor = PingPong->new( name => "Pong($_)", max => $max );

        my $ping = Stella::ActorProps->new( class => 'PingPong', args => { name => "Ping($_)", max => $max  } );
        my $pong = Stella::ActorProps->new( singleton => $PongActor );

        isa_ok($ping, 'Stella::ActorProps');
        isa_ok($pong, 'Stella::ActorProps');

        my $Ping = $ctx->spawn( $ping );
        my $Pong = $ctx->spawn( $pong );

        isa_ok($Ping, 'Stella::ActorRef');
        isa_ok($Pong, 'Stella::ActorRef');

        $ctx->send( $Ping, event *PingPong::Start, $Pong );

        pass('... starting test');
    }
}

# -----------------------------------------------------------------------------
# Lets-ago!
# -----------------------------------------------------------------------------

my $loop = Stella::ActorSystem->new( init => \&init );
isa_ok($loop, 'Stella::ActorSystem');

$loop->loop;

my $stats = $loop->statistics;

eq_or_diff($stats->{dead_letter_queue},[],'... the DeadLetterQueue is empty');
eq_or_diff($stats->{zombies},[],'... there are no Zombie actors');

done_testing();








