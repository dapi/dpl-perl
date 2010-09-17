#Объект возвращаемый контейнером
package dpl::Object;
use strict;
use Exporter;
use dpl::Base;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub init {
  my $self = shift;
  $self->{data} = shift;
  #  die join(',',%{$self->{data}});
  return $self;
#  return $self->SUPER::init(@_);
}

sub GetAction {
  $_[0]->{data}->{action};
}

sub GetTemplate  {
  $_[0]->{data}->{template};
}

sub GetProcessor {
  $_[0]->{data}->{processor};
}

sub GetTitle {
  $_[0]->{data}->{title};
}

sub GetDataToView {
  my $self = $_[0];
  return $self->GetData();
}

sub GetData {
  return $_[0]->{data};
}

sub GetPath {
  $_[0]->{data}->{path};
}

sub ID {
  $_[0]->{data}->{path};
}


1;
