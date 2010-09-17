package dpl::Web::Processor::Container;
use strict;
use Exporter;
use dpl::Web::User;
use dpl::Error;
use dpl::Context;
use dpl::Config;
use dpl::XML;
use dpl::Web::Processor::Access;
use dpl::Web::Container;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Processor::Access);

sub init {
  my $self = shift;
  $self->{c}=$self->GetContainer();
  return $self->SUPER::init(@_);
}

sub lookup {
  my ($self,$query) = @_;
  return 1 unless $self->{page}->{action} eq 'default';
  my $oid =  $self->{node}->hasAttribute('oid') ? $self->{node}->getAttribute('oid') : undef;
  return $self->{object} = $oid ? $self->{c}->GetObjectByID($oid) : $self->{c}->GetObjectByPath($query);
}

sub ACTION_default {
  my $self = shift;
  setContext('title',$self->{object}->GetTitle());
  setContext('oid',$self->{object}->ID());
  setContext('menupath',$self->{object}->GetMenuPath());
  return $self->{object}->GetData();
}


1;
