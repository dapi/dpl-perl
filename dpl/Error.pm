package dpl::Error;
use strict;
use Data::Dumper;
use dpl::Log;
use Exporter;
use Error;
use Carp;
use vars qw(@ISA
            @EXPORT
            $FATAL_ERROR);
@ISA = qw(Exporter
          Error);
@EXPORT = qw(fatal
             error);

sub new {
  my $self  = shift;
  local $Error::Depth = $Error::Depth + 1;
  return $self->SUPER::new(@_);
}

# �������� ��������� ���� ����� ��� ������������. �� 9 ���� 2005 ����

#sub new {
#  my $class =  shift;
#  my $self =  bless {@_}, $class; # @_� bless �� �������
#  return $self;
#}

sub stringify {
  my $self = shift;
  return exists $self->{-code} ? "$self->{text} ($self->{code})" : $self->{text};
}

sub fatal {
  print STDERR join(',',@_);
  #dpl::Log::logger()->fatal(join(',',@_));
  throw dpl::Error(text=>join(',',@_));
}

sub data {
  my $self=shift;
  return $self->{-data};
}

sub error {
  dpl::Log::logger()->error(@_);
  return undef;
}

1;
