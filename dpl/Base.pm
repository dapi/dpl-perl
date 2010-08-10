package dpl::Base;
use strict;
use dpl::Error;

sub new {
  my ($class,$name)=(shift,shift);
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{name} = $name;
  return $self;
}

sub init { return shift; }

sub time {
  my $self = shift;
  return @_ ? $self->{time} = shift : $self->{time};
}

#sub changeClass {
#  my ($self,$class) = @_;
#  return bless $self, $class;
  #  my $s = ref($self);
  #  my $c = ref($self);
  #  no strict;
  #  my $s_isa = *{"$s\::ISA"};
  #  my $c_isa = *{"$m\::ISA"};
  #  use strict;
#}

sub instance {
  my ($class,$name) = (shift,shift);
  my $self = $class->new($name,@_);
  return $self->init(@_);
}

#sub load { return shift; }

sub error {
  my $self = shift;
  my $err = dpl::Error->new(text=>shift);
  $err->throw();
}


1;
