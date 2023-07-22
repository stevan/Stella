# Stella

## Actors for Perl

Stella is an implementation of the [Actor Model](https://en.wikipedia.org/wiki/Actor_model) for Perl.

```perl

use Stella;

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
            $ctx->send( $message->from, Stella::Event->new( symbol  => *Pong ) );
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
            $ctx->send( $message->from, Stella::Event->new( symbol  => *Ping ) );
            $pongs++;
        }
        else {
            say "!!! ending Pong at($name)[$pongs] <= $max";
            _exit_both( $ctx, $message->from );
        }
    }
}

sub init ($ctx) {
    foreach ( 1 .. 10 ) {
        my $max = int(rand(10));

        my $Ping = $ctx->spawn( PingPong->new( name => "Ping($_)", max => $max ) );
        my $Pong = $ctx->spawn( PingPong->new( name => "Pong($_)", max => $max ) );

        $Ping->send( $Pong, Stella::Event->new( symbol => *PingPong::Pong ) );
    }
}

Stella::ActorSystem->new( init => \&init )->loop( 0.5 );

```


