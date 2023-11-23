
use v5.38;
use experimental 'class';

use Stella::Behavior;

class Stella::Actor::Remote :isa(Stella::Actor) {

    method behavior {
        Stella::Behavior->new
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Actor::Remote

=head1 DESCRIPTION

=cut
