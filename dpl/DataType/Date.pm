package dpl::DataType::Date;
use strict;
use Carp;

use dpl::DataType::DateObject;
use Exporter;
use vars qw(@ISA
            @MONTHS
            @WEEK_DAYS
            @EXPORT);

@ISA=qw(Exporter dpl::DataType::DateObject);
#    [qw(Января Февраля Марта Апреля Мая Июня Июля Августа Сентября Октября Ноября Декабря)];

sub Cmp
{
  my ($self, $date, $reverse) = @_;
  if(!ref($date))
    {
      $date = new Date::Handler({
                                 date => $date,
                                 time_zone => 'Europe/Moscow',
                                 locale=>'ru_RU.KOI8-R'
                                });

    }
  elsif($date->isa('Date::Handler'))
    {
    }
  elsif($date->isa($self->DELTA_CLASS()))
    {
      croak "Cannot compare a Date::Handler to a Delta.";
    }
  else
    {
      croak "Trying to compare a Date::Handler to an unknown object.";
    }
  my $d1 = 31*($self->Year()*12+$self->Month())+$self->Day();
  my $d2 = 31*($date->Year()*12+$date->Month())+$date->Day();
  return $d1 <=> $d2;

}

sub human {
  my $self = shift;
  return $self->SUPER::human(1);
#  return $self->TimeFormat("%e %B`%y");
}

sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d');
}

sub string {
  my $self = shift;
  return $self->TimeFormat('%e %B %Y');
}

sub AsScalar {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d');
}

1;
