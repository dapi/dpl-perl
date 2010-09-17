package dpl::Db::Filter::boolean;
use strict;
use dpl::Error;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);


#dpl::Db::Conf::addDefaultConfig({
#			     filters    => {
#					    boolean => 'type:numeric',
#					    # numeric -> 1,0
#					    # boolean -> yes,no
#					    # radio   -> on,off
#					   },
#			    });

sub ToSQL {
  my ($self,$value)=@_;
  my %b=(0=>0,1=>1);
  %b=(0=>'f',1=>'t')
    if $self->{type} eq 'pg';
  return $b{1} if $value==1 || $value eq 'yes' || $value eq 'on' || $value eq 'true' || $value eq 't';
  return $b{0};
}

sub FromSQL {
  my ($self,$value)=@_;
  return $value ? 1 : 0;
}


1;
