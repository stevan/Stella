package Stella::Tools;
use v5.38;

use Stella::Event;
use Stella::ActorRef;

use Stella::Tools::Debug;

use Exporter 'import';

our @EXPORT = qw[
    actor_isa
];

our @EXPORT_OK = (
    qw[ event ],
    @Stella::Tools::Debug::EXPORT
);

our %EXPORT_TAGS = (
    core   => [qw[ actor_isa ]],
    events => [qw[ event ]],
    debug  => [ @Stella::Tools::Debug::EXPORT ]
);

sub actor_isa ( $a, $isa ) { $a isa Stella::ActorRef && $a->actor_props->class->isa($isa) }

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

Stella::Tools

=head1 DESCRIPTION

=cut

