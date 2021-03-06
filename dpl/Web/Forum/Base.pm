package dpl::Web::Forum::Base;
use dpl::Error;
use strict;

sub new {
  my $class = shift;
  return  bless {}, $class; # @_� bless �� �������
}

# sub init {
#   my ($self,$id) = @_;
#   if (ref($id)) { $self->{data} = $id; $self->{id}=$id->{id}; } else { $self->{id} = $id; }
#   return $self;
# }

sub init { die "init is not defined"; }
	
sub instance {
  my $class = shift;
  my $self = $class->new();
#  print STDER "instance $class $self\n";
	return $self->init(@_);
}

sub Get {
	my $self = shift;
	fatal("No instance to do Get") unless $self->{data};
	return @_ ? $self->{data}->{$_[0]} : \%{$self->{data}};
}

1;
