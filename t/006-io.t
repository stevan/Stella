#!perl

use v5.38;
use experimental 'class';

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Util::Debug';

# ...

class Input :isa(Stella::Actor) {
    use Test::More;
    use Stella::Util::Debug;

    field $logger;

    ADJUST {
        $logger = Stella::Util::Debug->logger if LOG_LEVEL;
    }

    method Read ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Read" ) if INFO;

        my $w = $ctx->add_watcher(
            fh       => \*STDIN,
            poll     => 'r',
            callback => sub ($fh) {
                $logger->log_from( $ctx, WARN, "... STDIN is ready to read" ) if INFO;
                my $input = <$fh>;
                chomp $input;
                $logger->log_from( $ctx, WARN, "... read ($input) from STDIN, sending *Echo" ) if INFO;
                $ctx->send( $ctx, Stella::Event->new( symbol => *Echo, payload => [ $input ] ) );
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

    my $logger; $logger = Stella::Util::Debug->logger if LOG_LEVEL;

    my $Input = $ctx->spawn( Input->new );
    isa_ok($Input, 'Stella::ActorRef');

    $logger->log_from( $ctx, INFO, "...Sending *Read to Input within Timer(1)" ) if INFO;
    $ctx->send( $Input, Stella::Event->new( symbol => *Input::Read ) );

    my $i = $ctx->add_interval(
        timeout  => 1,
        callback => sub {
            state $x = 0;
            #$logger->log_from( $ctx, INFO, "...Sending *Echo to Echo within Interval($x)" ) if INFO;
            #$ctx->send( $Input, Stella::Event->new( symbol => *Input::Echo, payload => [ $x++ ] ) );
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








