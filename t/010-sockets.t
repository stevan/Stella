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

    use IO::Socket::SSL;
    use HTTP::Request;

    field $logger;

    ADJUST {
        $logger = Stella::Tools::Debug->logger if LOG_LEVEL;
    }

    method Read ($ctx, $message) {
        $logger->log_from( $ctx, INFO, "...got *Read" ) if INFO;

        my $socket = IO::Socket::SSL->new('www.google.com:443') || die 'Could not connect SSL to google';
           $socket->print( HTTP::Request->new( GET => '/' )->as_string );

        my $r;

        $logger->log_from( $ctx, INFO, "... Setting (30)s timeout while waiting on Socket " ) if INFO;
        my $t = $ctx->add_timer(
            timeout  => 30,
            callback => sub {
                $logger->log_from( $ctx, INFO, "... Timed out waiting for Socket" ) if INFO;
                fail('... unable to get response after 30(s)');
                $ctx->remove_watcher( $r );
                $ctx->exit;
                $socket->close;
            }
        );

        $r = $ctx->add_watcher(
            fh       => $socket,
            poll     => 'r',
            callback => sub ($socket) {
                $logger->log_from( $ctx, INFO, "... Socket is ready to read" ) if INFO;
                my $line = <$socket>;
                like($line, qr/200 OK/, '... got the correct response');
                $ctx->remove_watcher( $r );
                $ctx->exit;
                $t->cancel;
                $socket->close;
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
eq_or_diff($stats->{watchers},{ r => {}, w => {} },'... there are no watchers actors');

done_testing();

