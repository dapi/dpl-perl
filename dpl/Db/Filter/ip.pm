package dpl::Db::Filter::ip;
use strict;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);

sub ToSQL {
  my ($self,$value)=@_;
  return $value=~/\./ ? unpack("N", pack("C4", split(/\./, $value))) : $value;
}

sub FromSQL {
  my ($self,$value)=@_;
  return '' unless $value;
  return $value if $value=~/\./;
  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255);
}

1;
