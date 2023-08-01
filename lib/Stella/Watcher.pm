
use v5.38;
use experimental 'class';

class Stella::Watcher {
    use Carp 'confess';

    field $fh       :param;
    field $poll     :param;
    field $callback :param;

    ADJUST {
        -e $fh                  || confess "The `fh` param must exist";
        $poll =~ /^[rw]$/       || confess "The `fh` param must either `r` or `w`, not ($poll)";
        ref $callback eq 'CODE' || confess "The `callback` param must be a CODE ref, not ($callback)";
    }

    method fh       { $fh       }
    method poll     { $poll     }
    method callback { $callback }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Watcher

=head1 DESCRIPTION

=cut
