package Stella::Tools::Functions;
use v5.38;

use Carp 'confess';

use Exporter 'import';

our @EXPORT = qw[
    event
    actor_isa
    confess
];

our %EXPORT_TAGS = (

);

sub actor_isa ( $a, $isa ) { $a isa Stella::ActorRef && $a->actor isa $isa }

sub event ($symbol, @payload) {
    return Stella::Event->new(
        symbol  => $symbol,
        payload => [ @payload ]
    )
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Stella::Tools::Functions

=head1 DESCRIPTION

=cut

