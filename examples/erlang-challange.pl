#!perl

use v5.38;
use experimental 'class';

$|++;

use Time::HiRes 'time';

use Stella;
use Stella::Tools qw[ :events :debug ];

=pod

http://whealy.com/erlang/challenge.html

=cut

class ErlangTest :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools qw[ :events :debug ];

    field $id   :param;
    field $next :param = undef;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Ping ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Ping for ErlangTest : id($id) next(".($next // 'undef').")" ) if INFO;
        my $count = $message->event->payload->[0];
        if (defined $next) {
            $logger->log_from( $ctx, INFO, "... sending *Ping to next($next) with count($count)" ) if INFO;
            $ctx->send( $next, event *Ping => $count + 1 );
        }
        else {
            #say "Got the ping! count($count)";
        }
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Ping ] );
    }
}


our $NUM_PROCESSES = $ARGV[0] // 100;
our $NUM_MESSAGES  = $ARGV[1] // 100;

our $START = time;
our $MSG_START;

sub init ($ctx) {

    my $start = $ctx->spawn(Stella::ActorProps->new( class => 'ErlangTest', args => { id => 0 } ));

    my $t = $start;
    foreach my $id ( 1 .. $NUM_PROCESSES ) {
        $t = $ctx->spawn(Stella::ActorProps->new( class => 'ErlangTest', args => {
            id   => $id,
            next => $t,
        }));
    }

    $MSG_START = time();
    say "Process: ".($MSG_START - $START);

    $ctx->send( $t => event *ErlangTest::Ping => 0 ) foreach 1 .. $NUM_MESSAGES;

}

# -----------------------------------------------------------------------------
# Lets-ago!
# -----------------------------------------------------------------------------



my $loop = Stella::ActorSystem->new( init => \&init );
   $loop->loop;

say "Message: ".(time() - $MSG_START);
say "Runtime: ".(time() - $START);



__DATA__

ErlangChallenge.io

Test := Object clone do(
    next ::= nil
    id ::= nil
    ping := method(
        //writeln("ping ", id)
        if(next, next @@ping)
        yield
    )
)

max := 10000

t := Test clone

setup := method(
    for(i, 1, max,
        t := Test clone setId(i) setNext(t)
        t @@id
        yield
    )
)

writeln(max, " coros")
writeln(Date secondsToRun(setup), " secs to setup")
writeln(Date secondsToRun(t ping; yield), " secs to ping")
