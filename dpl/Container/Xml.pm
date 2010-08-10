package dpl::Container::Xml;
use strict;
use Exporter;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Container;
use dpl::Object;
use dpl::Context;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Container);

sub init {
  my ($self,$node,$page,$xml) = (shift,shift,shift,shift);
  $self->{last_oid}=100;
  $self->{xml}=$xml || context('site')->{site_node};
  return $self->SUPER::init($node,$page,@_);
}

sub lookup {
  my ($self,$page) = @_;
  die 'lookup is not implemented';
  my $record = $page->{oid} ?
    $self->GetRecordByID($page->{oid}) :
      $self->GetRecordByPath($page->{path}.$page->{tail});
  return undef unless $record;
  return dpl::Object->instance('web_object',$record,$self);
}

sub GetChildsByPath {
  my ($self,$path,$level) = @_;
  my $rec = $self->GetRecordByPath($path) || return undef;
  return $self->_getChilds($rec,$level || 999);
}

sub GetChildsByID {
  my ($self,$id,$level) = @_;
  die 'GetChildsByID is not implemented here';
}

sub _getChilds {
  my ($self,$rec,$level) = @_;
  $level--;
  my $q=".//page[\@menu]";
  my $nodes=$rec->{node}->findnodes($q);

  my @list;
  foreach my $a (@$nodes) {
    my $rec = $self->_getObject($a);
    $rec->{childs}=$self->_getChilds($rec,$level)
      if $level>0;
    push @list,$rec;
  }
  return \@list;
}


sub GetRecordByPath {
  my ($self,$path) = @_;
  #  my $q=".//page[\@path='$path' and \@menu]";
  my $q=".//page[\@path='$path']";
  my $node=$self->{xml}->findnodes($q)->pop();
  return $node ? $self->_getObject($node) : undef;
}

sub _getObject {
  my ($self,$node) = @_;
  my %h;
  $h{node}=$node;
  foreach (qw(path processor container template menu title oid)) {
    $h{$_}=$node->hasAttribute($_) ? xmlDecode($node->getAttribute($_)) : '';
  }
  $h{oid}=$self->generateOID() unless $h{oid};
  return \%h;
}

sub generateOID {
  my $self = shift;
  return $self->{last_oid}++;
}

#  my $tail = substr($p,length($path));
#   my $action = $node->hasAttribute('action') ? xmlDecode($node->getAttribute('action')) : 'default';
#   my $processor = $node->hasAttribute('processor') ? xmlDecode($node->getAttribute('processor')) : undef;
#   my $container = $node->hasAttribute('container') ? xmlDecode($node->getAttribute('container')) : undef;
#   my $oid = $node->hasAttribute('oid') ? xmlDecode($node->getAttribute('oid')) : undef;
#   my $template  = $node->hasAttribute('template') ? xmlDecode($node->getAttribute('template')) : undef;
# #  logger()->debug("Page is found. Path: $path, tail: $tail, processor: $processor, action: $action, template: $template");
#   return {node=>$node,path=>$path,tail=>$tail,
#           container=>$container,oid=>$oid,
# 	  processor=>$processor,template=>$template,action=>$action};


sub GetRecordByID {
  my ($self,$id) = @_;
  die 'GetRecordByID is not implemented here';
}

1;
