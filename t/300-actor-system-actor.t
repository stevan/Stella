#!perl

use v5.38;
use experimental 'class';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools', ':events';

use ok 'Stella::Actor::System';

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

    field $System :param;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Init ($ctx, $message) {
        $logger->log_from( $ctx, INFO, '*Init called' ) if INFO;

        $ctx->send(
            $System,
            event *Stella::Actor::System::Spawn, "Echo", *Start
        );
    }

    method Start ($ctx, $message) {
        my ($Echo) = $message->event->payload->@*;
        $logger->log_from( $ctx, INFO, '*Start called with Echo ActorRef('.$Echo.')' ) if INFO;

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
                $ctx->send( $System, event *Stella::Actor::System::Kill, $System );
                $ctx->exit;
            }
        );

    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Init, *Start ] );
    }
}


sub init ($ctx) {

    my $System      = $ctx->spawn( Stella::Actor::System->new );
    my $EchoChamber = $ctx->spawn( EchoChamber->new( System => $System ) );

    $ctx->send( $EchoChamber, event *EchoChamber::Init );
}


my $loop = Stella::ActorSystem->new( init => \&init );
isa_ok($loop, 'Stella::ActorSystem');

$loop->loop;

my $stats = $loop->statistics;

#warn Dumper $stats;

is_deeply($stats->{dead_letter_queue},[],'... the DeadLetterQueue is empty');
eq_or_diff($stats->{zombies},[],'... there are no Zombie actors');
eq_or_diff($stats->{watchers},{ r => {},w => {} },'... there are no watchers actors');

done_testing();








