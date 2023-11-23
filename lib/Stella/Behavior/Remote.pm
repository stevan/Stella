
use v5.38;
use experimental 'class';

class Stella::Behavior::Remote :isa(Stella::Behavior) {
    use Carp 'confess';

    ADJUST {

    }

    method apply ($, $, $message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        return;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Behavior::Remote

=head1 DESCRIPTION

=cut
