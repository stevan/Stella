#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';

# ...

class Foo :isa(Stella::Actor) {
    use Test::More;
    use Stella::Util::Debug;

    field $count = 0;
    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method Bar ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Bar" ) if INFO;
        pass('... we got the *Bar message');
        $count++;
        if ($count > 6) {
            fail("... we should not get more than ~5 messages, got ($count)");
        }
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Bar ] );
    }
}


sub init ($ctx) {

    my $Foo = $ctx->spawn( Foo->new );
    isa_ok($Foo, 'Stella::ActorRef');

    my $i = $ctx->add_interval(
        timeout  => 1,
        callback => sub { $ctx->send( $Foo, Stella::Event->new( symbol => *Foo::Bar ) ) }
    );

    my $t = $ctx->add_timer(
        timeout  => 5,
        callback => sub {
            $i->cancel;
            $ctx->kill( $Foo );
        }
    );
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








