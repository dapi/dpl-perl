package dpl::DataType::DateTime;
use strict;
use dpl::DataType::DateObject;
#use Exporter;
use base qw(dpl::DataType::DateObject);
# use vars qw(@ISA
#             @EXPORT);
#
# @ISA=qw(Exporter
#         dpl::DataType::DateObject);

#http://www.w3schools.com/schema/schema_dtypes_date.asp

sub Human {
  my $self = shift;
  return $self->TimeFormat("%e %B`%y %H:%M");
}


sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%dT%H:%M:%S');
}

sub string {
  my $self = shift;
  return die $self->TimeFormat('%Y-%m-%d %H:%M:%S');
}

sub AsScalar {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d %H:%M:%S');
}


1;
