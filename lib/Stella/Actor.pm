
use v5.38;
use experimental 'class';

use Stella::Behavior;

class Stella::Actor {

    method behavior {
        Stella::Behavior->new
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Actor

=head1 DESCRIPTION

The base L<Stella::Actor>, it will attempt to apply a L<Stella::Message> by
looking up the L<Stella::Message> event's symbol. In this case, the
L<Stella::Actor> will look for a method of the same name within it's
dispatch table.

L<Stella::Actor> is meant to be subclassed and methods added to enable
behaviors that can be called via an L<Stella::Event>.

=cut
