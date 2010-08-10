package dpl::Log::Apache;
use strict;
use Apache2::Log;
use base qw(dpl::Base);

sub init {
  my ($self) = @_;
  $self->{a} = Apache->server;
  return $self;
}

sub fatal {
  my $self = shift;
  $self->{a}->log->log_error(@_);
}

sub debug {
  my $self = shift;
  $self->{a}->log->log_debug(@_);
}

1;
