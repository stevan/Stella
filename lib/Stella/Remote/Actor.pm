
use v5.38;
use experimental 'class';

use Stella::Remote::Behavior;

class Stella::Remote::Actor :isa(Stella::Actor) {
    use Carp 'confess';

    field $post_office :param;

    ADJUST {
        $post_office isa Stella::Remote::PostOffice
            || confess 'The `post_office` param must be a Remote::PostOffice instance';
    }

    method behavior {
        Stella::Remote::Behavior->new( post_office => $post_office )
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Actor::Remote

=head1 DESCRIPTION

=cut
