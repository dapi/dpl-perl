package dpl::Container;
use strict;
#use Digest::MD5;
#use CGI::Cookie;
use dpl::Context;
#use dpl::Db::Table;
#use dpl::Db::Database;
use dpl::Base;
#use dpl::Web::Utils;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub init {
  my ($self) = @_;
  return $self;
}

sub GetChildsByPath {
  die 'not implemented';
}

sub lookup {
}

sub GetObjectByPath {
  my ($self,$path) = @_;
  die 'not implemented';
}

sub GetObjectByID {
  my ($self,$path) = @_;
  die 'not implemented';
}

sub GetFolderByPath {
  my ($self,$path) = @_;
  die 'not implemented';
}

sub GetFolderByID {
  my ($self,$path) = @_;
  die 'not implemented';
}



1;
