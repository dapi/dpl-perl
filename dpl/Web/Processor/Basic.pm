package dpl::Web::Processor::Basic;
use strict;
#use Apache::Constants;
use dpl::Error;
use dpl::XML;
use dpl::Log;
use dpl::Web::Processor;
use base qw(dpl::Web::Processor);

sub lookup {1;}

sub lookup_document {
  my ($self,$page_tail) = @_;
  $self->{page_tail} = $page_tail;
  $page_tail=~s/\.\.//;
  $page_tail=$self->getDefaultFileName() unless $page_tail;
  my $directory = xmlText($self->{node},'./directory');
  return undef unless -f $directory.$page_tail;
  $self->{file} = $directory.$page_tail;
}

sub getDefaultFileName { return 'default.html'; }

sub ACTION_default {
  my ($self) = @_;
  return $self->{file};
}


1;
