
use v5.38;
use experimental 'class';

class Stella::Remote::Behavior :isa(Stella::Behavior) {
    use Carp 'confess';

    has $post_office :param;

    ADJUST {
        $post_office isa Stella::Remote::PostOffice || confess 'The `post_office` param must be a Remote::PostOffice instance';
    }

    method apply ($, $, $message) {
        $message isa Stella::Core::Message || confess 'The `$message` arg must be a Message';

        $post_office->post_message( $message );

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
