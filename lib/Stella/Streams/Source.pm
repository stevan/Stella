
use v5.38;
use experimental 'class';

class Stella::Streams::Source {
    method get_next;
}

class Stella::Streams::Source::FromList :isa(Stella::Streams::Source) {
    use Carp 'confess';

    field $list :param;

    ADJUST {
        ref $list eq 'ARRAY' || confess 'The `$list` param must be a ARRAY ref';
    }

    method get_next { shift $list->@* }
}

class Stella::Streams::Source::FromGenerator :isa(Stella::Streams::Source) {
    use Carp 'confess';

    field $generator :param;

    ADJUST {
        ref $generator eq 'CODE' || confess 'The `$generator` param must be a CODE ref';
    }

    method get_next { $generator->() }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Streams::Source

=head1 DESCRIPTION

=cut
