# Stella

## Actors for Perl

Stella is an implementation of the [Actor Model](https://en.wikipedia.org/wiki/Actor_model) for Perl.

This started out as a [gist](https://gist.github.com/stevan/06a091d8ce775181e8c023864beba173) but I quickly decided that this path was fruitful and so created this module.

## Observability

Stella is built with observability in mind and comes with a logging library that is also used internally within Stella. More details to come, but for now, try this:

```shell
> STELLA_LOG=4 perl -I lib t/001-basic.t
```

The `STELLA_LOG` value can be set to 1 (`INFO`), 2 (`WARN`), 3 (`ERROR`), 4 (`DEBUG`) and will produce colorful log output, especially the `DEBUG` setting. It provides a fairly decent insight as to what is going in inside the `ActorSystem`.

## Example

```perl

use Stella;

class PingPong :isa(Stella::Actor) {
    use Stella::Tools::Debug; # import LOG_LEVEL, INFO, WARN, etc.

    field $name :param;  # so I can identify myself in the logs
    field $max  :param;  # the max number of ping/pong(s) to allow

    # counters for ping/pong(s)
    field $pings = 0;
    field $pongs = 0;

    field $logger;

    ADJUST {
        # create a logger if logging is enabled
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    my sub _exit_both ($ctx, $a) {  $ctx->exit; $ctx->kill( $a ) }

    method Ping ($ctx, $message) {
        if ($pings < $max) {
            $logger->log_from( $ctx, INFO, "got Ping($name)[$pings] <= $max" ) if INFO;
            $ctx->send( $message->from, Stella::Event->new( symbol  => *Pong ) );
            $pings++;
        }
        else {
            $logger->log_from( $ctx, WARN, "!!! ending Ping at($name)[$pings] <= $max" ) if WARN;
            _exit_both( $ctx, $message->from );
        }
    }

    method Pong ($ctx, $message) {
        if ($pongs < $max) {
            $logger->log_from( $ctx, INFO, "got Pong($name)[$pongs] <= $max" ) if INFO;
            $ctx->send( $message->from, Stella::Event->new( symbol  => *Ping ) );
            $pongs++;
        }
        else {
            $logger->log_from( $ctx, WARN, "!!! ending Pong at($name)[$pongs] <= $max" ) if WARN;
            _exit_both( $ctx, $message->from );
        }
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Ping, *Pong ] );
    }
}

sub init ($ctx) {
    # spawn 10 sets of Ping/Pong actors
    foreach ( 1 .. 10 ) {
        # give them a random max-pings
        my $max = int(rand(10));

        my $Ping = $ctx->spawn( PingPong->new( name => "Ping($_)", max => $max ) );
        my $Pong = $ctx->spawn( PingPong->new( name => "Pong($_)", max => $max ) );

        # start up this pair ...
        $Ping->send( $Pong, Stella::Event->new( symbol => *PingPong::Pong ) );
    }
}

Stella::ActorSystem->new( init => \&init )->loop;

```

## SEE ALSO

This is (yet another) implementation of an [ongoing project](https://github.com/stevan/ELO) of mine to make a sensible Actor system for Perl. This version uses the newly released – but still experimental – `class` feature of Perl v5.38.


