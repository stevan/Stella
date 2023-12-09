#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools', ':events';
use ok 'Stella::Tools::Debug';

class Echo :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools::Debug;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Echo ($ctx, $message) {
        $logger->log( INFO, "...got *Echo" ) if INFO;
        $message->from->send( $message->event );
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Echo ] );
    }
}

# ...

class Stella::Behavior::Future {
    use Carp 'confess';

    method apply ($actor, $ctx, $message) {
        $actor   isa Stella::Actor         || confess 'The `$actor` arg must be an Actor';
        $ctx     isa Stella::Core::Context || confess 'The `$ctx` arg must be an ActorContext';
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        $actor->success( $ctx, $message->event );
    }
}

class Future :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools::Debug;

    field $result;
    field $on_success;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method on_success ($f) { $on_success = $f; $self; }

    method success ($ctx, $event) {
        $result = $event;
        $on_success->($event) if $on_success;
        $ctx->exit;
    }

    method behavior {
        Stella::Behavior::Future->new;
    }
}


# https://soft.vub.ac.be/amop/at/tutorial/actors#futures
# https://en.wikipedia.org/wiki/Futures_and_promises#Semantics_of_futures_in_the_actor_model
# https://docs.oracle.com/en/java/javase/19/docs/api/java.base/java/util/concurrent/Future.html

# More this to Context, then I can use
# the internal $system instead of the $ctx
# argument here
sub future ($ctx, $producer) { # TODO - add timeout
    my $future     = Future->new;
    my $future_ref = $ctx->spawn(Stella::ActorProps->new( singleton => $future ));
    $producer->(
        Stella::Core::Context->new(
            system    => $ctx->system,
            actor_ref => $future_ref
        )
    );
    $future;
}

sub init ($ctx) {

    my $Echo = $ctx->spawn(Stella::ActorProps->new( class => 'Echo' ));

    my $f = future($ctx, sub ($ctx) {
        $ctx->send( $Echo, event *Echo::Echo => 'Welcome to the Future!' );
    });

    $f->on_success(sub ($event) {
        pass("... ON SUCCESS: $event");
        $ctx->kill($Echo);
    });

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








