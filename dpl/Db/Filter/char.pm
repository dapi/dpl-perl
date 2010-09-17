package dpl::Db::Filter::char;
use strict;
use dpl::XML;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);

sub init {
  my ($self) = @_;
  #  my $c = xmlChildToHash($self->{config});
  #  die join(',',%$c);
  #  $self->{s} = Data::Serializer->new(%$c);
  return $self;
}


sub ToSQL {
  my ($self,$value)=@_;
  return "$value";
}

sub FromSQL {
  my ($self,$value)=@_;
  return "$value";
}

1;
