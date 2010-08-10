package dpl::Db::Filter::boollog;
use strict;
use dpl::Error;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);

sub ToSQL {
  my ($self,$value)=@_;

  return '' unless defined  $value;
  fatal("Неверное значение типа boollog - должен быть массив (ref($value),$value)")
    unless ref($value)=~/array/i;
  my $str;
  return undef unless $value;
  foreach (@$value) {
    if (defined $_) {
      $str.=$_ ? 1 : 0;
    } else {
      $str.=' ';
    }
  }
  return $str;
}

sub FromSQL {
  my ($self,$value)=@_;
  my @a;
  foreach (map {chr($_)} unpack('c*',$value)) {
    if ($_ eq ' ') {
      push @a, undef;
    } elsif ($_==1) {
      push @a,1;
    } elsif ($_==0) {
      push @a,0;
    } else {
      fatal("Неизвестное значение - '$_'");
    }
  }
  return \@a;
}


1;
