package dpl::DataType::Time;
use strict;
use dpl::DataType::DateObject;
#use Exporter;
use base qw(dpl::DataType::DateObject);

sub Human {
  my $self = shift;
  return $self->TimeFormat("%H:%M");
}

sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%H:%M:%S');
}

sub string {

  my $self = shift;
  return $self->AsScalar();
  return $self->TimeFormat('%H:%M:%S');
}

sub AsScalar {
  my $self = shift;
  my $s = $self->TimeFormat('%H:%M:%S');
  $s=~s/:00$//;
  return $s;
}



1;
