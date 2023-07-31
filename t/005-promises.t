#!perl

use v5.38;
use experimental 'class', 'try';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Util::Debug';

# ...

class Service :isa(Stella::Actor) {
    use Test::More;
    use Stella::Util::Debug;
    use Data::Dumper;

    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method Request ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "... got *Request" ) if INFO;

        my $event = $message->event;
        my ($action, $args, $promise) = $event->payload->@*;

        $logger->log_from( $ctx, INFO, "got args ($action, [".(join ',', @$args)."] $promise)" ) if INFO;

        my ($x, $y) = @$args;
        try {
            $ctx->next_tick(sub {
            $promise->resolve(
                Stella::Event->new(
                    symbol  => *Response,
                    payload => [
                        ($action eq 'add') ? ($x + $y) :
                        ($action eq 'sub') ? ($x - $y) :
                        ($action eq 'mul') ? ($x * $y) :
                        ($action eq 'div') ? ($x / $y) :
                        die "Invalid Action: $action"
                    ]
                )
            );
            });
            $logger->log_from( $ctx, INFO, "Promise resolved!" ) if INFO;
        } catch ($e) {
            chomp $e;
            $logger->log_from( $ctx, INFO, "Error running service: $e" ) if INFO;
            $promise->reject(
                Stella::Event->new( symbol => *Error, payload => [ $e ] )
            );
        }
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Request ] );
    }
}


sub init ($ctx) {

    my $logger; $logger = Stella::Util::Debug->logger if LOG_LEVEL;

    my $Service = $ctx->spawn( Service->new );
    isa_ok($Service, 'Stella::ActorRef');

    my $promise = $ctx->promise;
    isa_ok($promise, 'Stella::Promise');

    $ctx->send( $Service,
        Stella::Event->new(
            symbol  => *Service::Request,
            payload => [ add => [ 2, 2 ], $promise ]
        )
    );

    $promise->then(
        sub ($result) {
            $logger->log_from( $ctx, INFO, "... promise resolved!" ) if INFO;

            isa_ok($result, 'Stella::Event');

            is($result->symbol, *Service::Response, '... got the expected result type');

            my ($val) = $result->payload->@*;
            is($val, 4, '... got the expected result');
        },
        sub ($error)  {
            $logger->log_from( $ctx, INFO, "... promise rejected!" ) if INFO;

            isa_ok($error, 'Stella::Event');

            is($error->symbol, *Service::Error, '... got the expected error type');

            my ($err) = $error->payload->@*;

            fail('... got an unexpected error: '.$err);
        },
    )->then(sub ($) {
        $logger->log_from( $ctx, INFO, "Promise has been handled, killing service" ) if INFO;
        $ctx->kill( $Service );
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








