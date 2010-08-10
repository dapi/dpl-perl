package dpl::Web::Processor::Access;
use strict;
use Exporter;
use dpl::Web::User;
use dpl::Error;
use dpl::Context;
use dpl::System;
use dpl::Config;
use dpl::XML;
use dpl::Web::Processor::Session;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Processor::Session);

# В дочернем классе необходимо прописать следующие функции:
# LoadUser

sub LoadUser {
  my $self = shift;
  my $res = $self->SUPER::LoadUser(@_);
  setContext('access',$self->user()->GetAccesses())
    if $self->user()->IsLoaded();
#  my $a=context('access');
#  die join(',',%$a);
  return 1;
}

sub init {
  my $self = shift;
  $self = $self->SUPER::init(@_);
  return undef unless $self;
  #  die setting('subsystem');
  $self->LoadUser()
    unless $self->user()->IsLoaded();
  return $self;
}

sub execute {
  my ($self,$action) = (shift,shift);
  startTimer('processor');
  $self->{action}=$action if $action;
  $action=$self->{action} || $self->{page}->{action};
  setting('action',$action);
  return $self->SUBACTION_no_access()
    unless $self->CheckAccess($action);
  if ($self->preaction($action)) {
    my $ref = $self->can("ACTION_$action") || $self->fatal("No such action: $action");
    $self->{result}=&$ref($self,@_);
    $self->postaction($action);
  }
  stopTimer('processor');
  return $self->{result};
}

sub getAccessAttr {
  my $self = shift;
  my $node = shift;
  return $node->hasAttribute('access') ? xmlDecode($node->getAttribute('access')) : undef;
}

sub setAcccessForPage {
  my ($self,$access) = @_;
  return $self->{access_for_page} = $access;
}

sub getAccessForPage {
  my $self = shift;
  my $action = shift;
  return $self->{access_for_page} if $self->{access_for_page};
  my $ref = $self->can("ACCESS_$action");
  return &$ref($self,$action) if $ref;
  return $self->getAccessAttr($self->{page}->{node}) || $self->getAccessAttr(context('site')->{site_node});
}

sub CheckAccess {
  my ($self,$action) = @_;
  my $access = $self->getAccessForPage($action);
  return 1 unless $access;
  return $self->SUBACTION_no_access(1)
    unless $self->user()->IsLoaded();
  my $res = $self->user()->HasAccess($access);
  return $res;
}

sub SUBACTION_no_access {
  my ($self,$no_user) = @_;
  #  print STDERR "NO ACCESS\n";
  setContext('no_access',1);
  setContext('back',$self->{page}->{path});
#  die join(',',%{$self->{page}});
  $self->template('no_login');
  return 0;
}


1;
