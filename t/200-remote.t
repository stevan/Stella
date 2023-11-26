#!perl

use v5.38;
use experimental 'class';

use Data::Dumper;

use Test::More;
use Test::Differences;

use ok 'Stella';
use ok 'Stella::Tools', ':events';

use ok 'Stella::Remote::Actor';
use ok 'Stella::Remote::PostOffice';

sub Test {}

sub init ($ctx) {

    my $post_office = Stella::Remote::PostOffice->new;

    my $remote = $ctx->spawn(Stella::ActorProps->new(
        class => 'Stella::Remote::Actor',
        args  => { post_office => $post_office }
    ));

    $ctx->send( $remote => event *Test );

    $ctx->next_tick(sub {
        # we have to do this double next-tick because
        # they will be processed before the `send`
        # above happens, so we just use this to
        # skip to the next-next-tick
        $ctx->next_tick(sub {
            my @outgoing = $post_office->outgoing;
            is(scalar @outgoing, 1, '... got the expected number of outgoing messages');
            is($outgoing[0]->event->symbol, *Test, '... got the expected message');
            is($outgoing[0]->to, $remote, '... got the expected recipient');

            $ctx->kill( $remote );
        });
    });
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








