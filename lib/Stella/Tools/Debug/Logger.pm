
use v5.38;
use experimental 'class', 'builtin';
use builtin 'blessed';

class Stella::Tools::Debug::Logger {
    use Term::ReadKey qw[ GetTerminalSize ];

    our $TERM_WIDTH = (GetTerminalSize())[0];

    state %level_color_map = (
        1 => "\e[96m",
        2 => "\e[93m",
        3 => "\e[91m",
        4 => "\e[92m",
    );
    state %level_map = (
        1 => $level_color_map{1}.".o(INFO)\e[0m",
        2 => $level_color_map{2}."^^[WARN]\e[0m",
        3 => $level_color_map{3}."!{ERROR}\e[0m",
        4 => $level_color_map{4}."?<DEBUG>\e[0m",
    );

    field $fh :param = \*STDERR;

    method log_from ($actor_ref, $level, @msg) {
        state %pid_to_color = ( 1 => [100,100,100]);

        $fh->print(
            $level_map{ $level },
            (sprintf " \e[20m\e[97m\e[48;2;%d;%d;%d;m %03d:%s \e[0m " => (
                @{ $pid_to_color{ $actor_ref->pid }
                    //= [ map { (int(rand(20)) * 10) } 1,2,3 ] },
                # TODO: Replace this below with $actor_ref->to_string
                $actor_ref->pid,
                (blessed $actor_ref->actor eq 'Stella::Actor'
                    ? 'INIT'
                    : blessed $actor_ref->actor),
            )),
            $level_color_map{ $level }, @msg, "\e[0m",
            "\n"
        );
    }

    method line ($label) {
        my $width = ($TERM_WIDTH - ((length $label) + 2 + 2));
        $fh->print(
            "\e[38;2;125;125;125;m",
            '-- ', $label, ' ', ('-' x $width),
            "\e[0m",
            "\n"
        );
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Tools::Debug::Logger

=head1 DESCRIPTION

=cut
