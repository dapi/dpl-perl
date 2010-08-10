package dpl::Db::Filter::numeric;
use strict;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);


sub new {
  my ($class,$name,$conf) = @_;
  return bless {config=>$conf}, $class;
}

sub ToSQL {
  my ($self,$value)=@_;
  return undef unless defined $value;
  return undef if $value eq '';
  # $value+=0; TODO �������� � ������������ - , ��� .
  # TODO
  # ������� � �������
  $value=~s/\,/\./g;
  return $value;
}
sub FromSQL {
  my ($self,$value)=@_;
  return undef unless defined $value;
  #  TODO ��������� ������
  $value=~s/\,/\./g;
  return $value+=0;
}

1;
