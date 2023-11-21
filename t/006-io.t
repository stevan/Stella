#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools::Debug';

# ...

class Input :isa(Stella::Actor) {
    use Test::More;
    use Stella::Tools::Debug;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Read ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Read" ) if INFO;

        my $w = $ctx->add_watcher(
            fh       => \*STDIN,
            poll     => 'r',
            callback => sub ($fh) {
                $logger->log_from( $ctx, INFO, "... STDIN is ready to read" ) if INFO;
                my $input = <$fh>;
                chomp $input;
                $logger->log_from( $ctx, INFO, "... read ($input) from STDIN, sending *Echo" ) if INFO;
                $ctx->send( $ctx->actor_ref, Stella::Event->new( symbol => *Echo, payload => [ $input ] ) );
            }
        );

        $logger->log_from( $ctx, INFO, "... Setting (5)s timeout while waiting on STDIN " ) if INFO;
        $ctx->add_timer(
            timeout  => 5,
            callback => sub {
                $logger->log_from( $ctx, INFO, "... Timed out waiting for STDIN" ) if INFO;
                $ctx->remove_watcher( $w );
                $ctx->exit;
            }
        );
    }

    method Echo ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Echo" ) if INFO;
        $logger->log_from( $ctx, INFO, "Message Payload: [".(join ', ' => $message->event->payload->@*)."]" ) if INFO;
    }

    method behavior {
        Stella::Behavior::Method->new( allowed => [ *Read, *Echo ] );
    }
}

sub init ($ctx) {

    my $logger; $logger = Stella::Tools::Debug->logger if LOG_LEVEL;

    my $Input = $ctx->spawn( Input->new );
    isa_ok($Input, 'Stella::ActorRef');

    $logger->log_from( $ctx, INFO, "...Sending *Read to Input within Timer(1)" ) if INFO;
    $ctx->send( $Input, Stella::Event->new( symbol => *Input::Read ) );
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
eq_or_diff($stats->{watchers},{ r => {},w => {} },'... there are no watchers actors');

done_testing();








