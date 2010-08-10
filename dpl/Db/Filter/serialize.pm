package dpl::Db::Filter::serialize;
use strict;
use dpl::XML;
use vars qw(@ISA);
use Data::Serializer;
@ISA = qw(Exporter dpl::Base);

sub init {
  my ($self) = @_;
  my $c = xmlChildToHash($self->{config});
  $self->{s} = Data::Serializer->new(%$c);
  return $self;
}

sub ToSQL {
  my ($self,$data)=@_;
  return $self->{s}->serialize($data);
}

sub FromSQL {
  my ($self,$data)=@_;
  return $self->{s}->deserialize($data);
}

=pod


    my $str = $data->{$s->{name}};
  $str.=';' if $str;
  my $v = $self->{attr}->{$key}->{filter} ? $self->{attr}->{$key}->{filter}->ToSQL($data->{$key}) : $data->{$key};
  $str.="$key=$v";
  $data->{$s->{name}}=$str;
  delete $data->{$key};
}


sub deserialize {
  my ($self,$key,$data)=@_;
  my $s = $self->{sers}->{$key};
  my $str = $data->{$key};
  foreach (split(/;/,$str)) {
    my ($k,$v)=split(/=/,$_);
    $data->{$k} = $self->{attr}->{$k}->{filter} ? $self->{attr}->{$k}->{filter}->FromSQL($v) : $v;
  }
  delete $data->{$key};


=cut

1;
