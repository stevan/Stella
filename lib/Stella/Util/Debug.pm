package Stella::Util::Debug;
use v5.38;

use Stella::Util::Debug::Logger;

use constant LOG_LEVEL => $ENV{STELLA_DEBUG} ? 4 : ($ENV{STELLA_LOG} // 0);

use constant INFO  => (LOG_LEVEL >= 1 ? 1 : 0);
use constant WARN  => (LOG_LEVEL >= 2 ? 2 : 0);
use constant ERROR => (LOG_LEVEL >= 3 ? 3 : 0);
use constant DEBUG => (LOG_LEVEL >= 4 ? 4 : 0);

use Exporter 'import';

our @EXPORT = qw[
    DEBUG
    INFO
    WARN
    ERROR

    LOG_LEVEL
];

sub logger ($class, @args) {
    state $logger = Stella::Util::Debug::Logger->new( @args )
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Util::Debug

=head1 DESCRIPTION

=cut
