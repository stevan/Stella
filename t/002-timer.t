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

    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method Bar ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Bar" ) if INFO;
        pass('... we got the *Bar message');
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Bar ] );
    }
}


sub init ($ctx) {

    my $Foo = $ctx->spawn( Foo->new );
    isa_ok($Foo, 'Stella::ActorRef');

    my $t1 = $ctx->add_timer(
        timeout  => 1,
        callback => sub { $ctx->send( $Foo, Stella::Event->new( symbol => *Foo::Bar ) ) }
    );

    my $t3 = $ctx->add_timer(
        timeout  => 3,
        callback => sub { fail('This timer(3) should never happen') }
    );

    my $t2 = $ctx->add_timer(
        timeout  => 2,
        callback => sub {
            $t3->cancel;
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








