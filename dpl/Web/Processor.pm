package dpl::Web::Processor;
use strict;
use Exporter;
use dpl::Error;
use dpl::Context;
use dpl::Config;
use dpl::System;
use dpl::Error;
#use dpl::Log;
use dpl::Base;
use dpl::Web::Utils;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub init {
  my ($self,$node,$page) = @_;
  $self->{page} = $page;
  $self->{node} = $node || $self->fatal("No processor's node");
  my %data;
  $data{title}=xmlDecode($page->{node}->getAttribute('title'))
    if $page->{node}->hasAttribute('title');
  $self->{data} = \%data;
  $self->{view_options}={};
  return $self;
}

sub deinit { 1; }

sub lookup { 1; }

sub template {
  my ($self,$templ,$file) = @_;
  return $self->{template} unless $templ;
  $self->{template_file}=$file if $file;
  return $self->{template}=$templ;
}

sub template_file {
  my $self = shift;
  return @_ ? $self->{template_file}=shift : $self->{template_file};
}

sub data {
  my $self = shift;
  return $self->{data};
}

sub setViewOptions {
  my ($self,$key,$value) = @_;
  return $self->{view_options}->{$key} = $value;
}

sub getViewOptions {
  my ($self,$key) = @_;
  return $self->{view_options}->{$key};
}

sub viewOptions {
  my $self = shift;
  return $self->{view_options};
}

sub fatal {
  my $self = shift;
  unshift @_,"processor:$self->{name}" if $self=~/HASH/;
  dpl::Error::fatal(@_);
}

sub preaction { 1 }

sub postaction { 1 }

sub execute {
  my ($self,$action) = (shift,shift);
  startTimer('processor');
  $self->{action}=$action if $action;
  $action=$self->{action} || $self->{page}->{action};
  setting('action',$action);
  if ($self->preaction($action)) {
    my $ref = $self->can("ACTION_$action") || $self->fatal("No such action: $action");
    $self->{result}=&$ref($self,@_);
    $self->postaction($action);
  }
  stopTimer('processor');
  return $self->{result};
}

sub subexecute {
  my ($self,$action) = (shift,shift);
  $self->{subaction}=$action;
  setting('subaction',$action);
  my $ref = $self->can("ACTION_$action") || $self->fatal("No such subaction: $action");
  $self->{result}=&$ref($self,@_);
  delete $self->{subaction};
  return $self->{result};
}


sub getCookies {
  my $self = shift;
  return $self->{set_cookie};
}

sub addCookie {
  my ($self,$cookie) = @_;
  return $cookie unless $cookie;
  if ($self->{set_cookie}) {
#    print STDERR "addCookie2 ($self->{set_cookie}): '$cookie'\n";
    $self->{set_cookie}=[$self->{set_cookie}]
      unless ref($self->{set_cookie})=~/array/i;
    push @{$self->{set_cookie}},$cookie;
  } else {
#    print STDERR "addCookie: $cookie\n";
    return $self->{set_cookie} = $cookie;
  }
}




1;
