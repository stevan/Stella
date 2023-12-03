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
        $logger->log_from( $ctx, INFO, "...got *Echo" ) if INFO;
        $ctx->send( $message->from, $message->event );
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

class FutureActor :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools::Debug;

    field $producer :param;

    field $result;
    field $on_success :param;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method start ($ctx) {
        $producer->($ctx);
    }

    method success ($ctx, $event) {
        $result = $event;
        $on_success->($event) if $on_success;
        $ctx->exit;
    }

    method behavior {
        Stella::Behavior::Future->new;
    }
}

sub init ($ctx) {

    my $Echo = $ctx->spawn(Stella::ActorProps->new( class => 'Echo' ));

    my $f = FutureActor->new(
        producer => sub ($ctx) {
            $ctx->send( $Echo, event *Echo::Echo => 'Welcome to the Future!' );
        },
        on_success => sub ($event) {
            pass("... ON SUCCESS: $event");
            $ctx->kill($Echo);
        }
    );
    my $Future = $ctx->spawn(Stella::ActorProps->new( singleton => $f ));
    $f->start(Stella::Core::Context->new( system => $ctx->system, actor_ref => $Future ));

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








