#!perl

use v5.38;
use experimental 'class';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools', ':events';

use ok 'Stella::Node';

class Echo :isa(Stella::Actor) {
    use Stella::Tools qw[ :events :debug ];

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Echo ($ctx, $message) {
        my ($msg) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Echo called with Msg('.$msg.')' ) if INFO;
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Echo ] );
    }
}

class EchoChamber :isa(Stella::Actor) {
    use Stella::Tools qw[ :events :debug ];

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Init ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*Init called' ) if INFO;

        my $System = $ctx->system->lookup_actor( 2 );

        $ctx->send(
            $System,
            event *Stella::Actor::System::Spawn, "Echo", *Start
        );
    }

    method Start ($ctx, $message) {
        my ($Echo) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Start called with Echo ActorRef('.$Echo.')' ) if INFO;

        my $System = $ctx->system->lookup_actor( 2 );

        my $x = 0;
        my $t1 = $ctx->add_interval(
            timeout  => 1,
            callback => sub {
                $ctx->send(
                    $System,
                    event *Stella::Actor::System::Send,
                        $Echo,
                        $System,
                        event *Echo::Echo, "Hello World (".+$x++.")"
                );
            }
        );

        my $t2 = $ctx->add_timer(
            timeout  => 3,
            callback => sub {
                $t1->cancel;
                $ctx->send( $System, event *Stella::Actor::System::Kill, $Echo );
            }
        );

    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Init, *Start ] );
    }
}


sub init ($ctx) {
    my $EchoChamber = $ctx->spawn( EchoChamber->new );

    $ctx->send( $EchoChamber, event *EchoChamber::Init );
}


my $node = Stella::Node->new( system_init => \&init );
isa_ok($node, 'Stella::Node');

warn Dumper $node->start;

done_testing();








