package dpl::Web::Processor::Db;
use strict;
use Exporter;
use dpl::Error;
use dpl::Context;
use dpl::Config;
use dpl::Error;
use dpl::Log;
use dpl::Base;
use dpl::Web::Utils;
use dpl::XML;
use dpl::Db::Database;

use dpl::Web::Processor::CGI;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Processor::CGI);

sub init {
  my $self = shift;
  $self=$self->SUPER::init(@_);
  $self->{db}=db()->Connect(xmlDecode($self->{node}->getAttribute('db')))
    if $self->{node}->hasAttribute('db');
  return $self;
}

sub deinit {
  my ($self,$is_ok) = @_;

  my $db = $self->{db} || db();
#  print STDERR "Processor: deinit ($db) ($is_ok)\n";
  if (UNIVERSAL::isa($db, 'dpl::Db::Database')) {
    if ($is_ok) {
      $db->Commit();
    } else {
      $db->Rollback();
    }
    # Убрал дабы посмотреть как отразится на повторном коннекте
    #    $db->Disconnect();
  }
  return 1;
}

1;
