package dpl::Web::Processor::File;
use strict;
#use Apache::Constants;
use dpl::Web::Error;
use dpl::Web::XML;
use dpl::Web::Log;
use dpl::Web::Processor;
use base qw(Web::Processor);

sub ACTION_file {
  my ($self,$page) = @_;
  my $dir = xmlText($self->{node},'directory');
  my $file = xmlText($page,'file');
  return $dir.$file if $file;
  die $self->{path}->{executed};
  log_debug("Use executed path as file: $file");
  $file='default.html' unless $file;
  return $file;
}

1;
