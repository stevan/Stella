#!perl

use v5.38;
use experimental 'class';

use Test::More;

use ok 'Stella';

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

    field $name :param;  # so I can identify myself in the logs
    field $max  :param;  # the max number of ping/pong(s) to allow

    # counters for ping/pong(s)
    field $pings = 0;
    field $pongs = 0;

    my sub _exit_both ($ctx, $a) {  $ctx->exit; $ctx->kill( $a ) }

    method Ping ($ctx, $message) {
        if ($pings < $max) {
            say "got Ping($name)[$pings] <= $max";
            $ctx->send( $message->from, Stella::Event->new( symbol => *Pong ) );
            $pings++;
        }
        else {
            say "!!! ending Ping at($name)[$pings] <= $max";
            _exit_both( $ctx, $message->from );
        }
    }

    method Pong ($ctx, $message) {
        if ($pongs < $max) {
            say "got Pong($name)[$pongs] <= $max";
            $ctx->send( $message->from, Stella::Event->new( symbol => *Ping ) );
            $pongs++;
        }
        else {
            say "!!! ending Pong at($name)[$pongs] <= $max";
            _exit_both( $ctx, $message->from );
        }
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

        my $Ping = $ctx->spawn( PingPong->new( name => "Ping($_)", max => $max ) );
        my $Pong = $ctx->spawn( PingPong->new( name => "Pong($_)", max => $max ) );

        $Ping->send( $Pong, Stella::Event->new( symbol => *PingPong::Pong ) );
    }
}

# -----------------------------------------------------------------------------
# Lets-ago!
# -----------------------------------------------------------------------------

Stella::ActorSystem->new( init => \&init )->loop( $ENV{DEBUG} ? 0.5 : () );

done_testing();








