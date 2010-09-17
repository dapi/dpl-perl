package dpl::Db::Filter;
use strict;
use locale;
use dpl::Context;
use dpl::Log;
use dpl::Error;
use dpl::XML;
use dpl::Db::Database;
use dpl::Db::Filter::char;
use dpl::Db::Filter::boolean;
use dpl::Db::Filter::boollog;
use dpl::Db::Filter::numeric;
use dpl::Db::Filter::date;
use dpl::Db::Filter::ip;
use dpl::Db::Filter::serialize;

use vars qw(@EXPORT
	    @ISA);

@EXPORT = qw(filter);

@ISA = qw(Exporter
	  dpl::Base);

sub filter {
  my $name = shift;
  return context('filters',
		 $name) || setContext('filters',$name,
				      dpl::Db::Filter->instance($name));
}

sub init {
  my $self = shift;
  my $conf = db()->{config};
  my $node = $conf->findnodes("./filters/filter[\@name='$self->{name}']")->pop()
    || fatal("No config node for filter: $self->{name}");
  my $handler = xmlDecode($node->getAttribute('handler'));

  $self = bless $self, $handler;
  $self->{config} = $node;
  $self->{type} = xmlDecode($node->getAttribute('type'))
    if $node->hasAttribute('type');
  return $self->init(@_);
}

1;
