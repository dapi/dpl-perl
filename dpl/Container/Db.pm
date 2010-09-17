package dpl::Container::Db;
use strict;
use Exporter;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Context;
use dpl::Container;
use dpl::Object;
use dpl::Log;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Container);

sub init {
  my $self = shift;
  return $self->SUPER::init(@_);
}

sub lookup {
  my ($self,$page) = @_;
  my $record = $page->{oid} ?
    $self->GetRecordByID($page->{oid}) :
      $self->GetRecordByPath($page->{path}.$page->{tail});
  return undef unless $record;
  return dpl::Object->instance('web_object',$record,$self);
}

sub GetOwnerAndChildsByPath {
  my ($self,$path,$level,$get_all) = @_;
  my $rec = $self->GetRecordByPath($path,$get_all) || return undef;
  $self->{parent_selected}=0;
  $rec->{childs}=$self->_getChilds($rec->{id},$level || 999,$get_all);

  $rec->{is_current}= setting('uri')->{page_tail} eq $rec->{path};
  $rec->{is_selected}=$self->{parent_selected};
  return $rec;
}

sub GetOwnerAndChildsByID {
  my ($self,$id,$level,$get_all) = @_;
  my $rec = $self->GetRecordByID($id,$get_all) || return undef;
  $self->{parent_selected}=0;
  $rec->{childs}=$self->_getChilds($rec->{id},$level || 999,$get_all);
  $rec->{is_current}= setting('uri')->{page_tail} eq $rec->{path};
  $rec->{is_selected}=$self->{parent_selected};
  return $rec;
}

sub GetChildsByPath {
  my ($self,$path,$level,$get_all) = @_;
  my $rec = $self->GetRecordByPath($path,$get_all) || return undef;
  return $self->_getChilds($rec->{id},$level || 999,$get_all);
}

sub GetChildsByID {
  my ($self,$id,$level,$get_all) = @_;
  $self->{is_selected}=0;
  return $self->_getChilds($id,$level || 999,$get_all);
}

sub _getChilds {
  my ($self,$id,$level,$get_all) = @_;
  $level--;
  my $table = $self->ObjectTable();
  my $db = db();
  my $f = $get_all ? '' : 'and is_active';
  my $p = $id ? "parent_id=$id" : "parent_id is null";
  my $sth = $db->Query("select * from $table where $p and menu is not null $f order by menu");
  my @list;
  my $p = setting('uri')->{page_tail};
  my $parent_selected=0;
  while (my $a = $db->Fetch($sth)) {
    $a->{timestamp}=filter('timestamp')->FromSQL($a->{timestamp});
    $a->{oid}=$a->{id};
    if ($p eq $a->{path}) {
      $a->{is_current}=1;
      $a->{is_selected}=1;
      $parent_selected=1;
    }
    if ($level>0) {
      $a->{childs}=$self->_getChilds($a->{id},$level,$get_all);
    }
    if ($self->{parent_selected}) {
      $a->{is_selected}=1;
      $self->{parent_selected}=0;
    }
    push @list,$a;
  }
  $self->{parent_selected}=$parent_selected;
  return \@list;
}

sub ObjectTable {
  return 'web_object';
}

sub GetRecordByPath {
  my ($self,$path) = @_;
  my $res = table(ObjectTable())->Load({path=>$path,is_active=>1});
  return $res if $res;
  my $p = $path;
  while ($p=~s/\/[^\/]+\/?$//) {
    logger()->debug("éİÅÍ ÓÕÂËÏÎÔÅÊÎÅÒ $p/");
    my $res = table(ObjectTable())->
      Load([{path=>"$p/",is_active=>1},"container is not null"]);
    next unless $res;
    my $container = context('site')->
      lookupContainer($res->{container})
        || $self->fatal("Can't init container: $res->{container}");
    my $tail =  substr($path,length("$p/"));
    return $container->
      lookup({path=>"$p/",
              tail=>$tail});
  }
  return undef;
}

sub GetRecordByID {
  my ($self,$id) = @_;
  my $rec = table(ObjectTable())->Load($id);
  $rec->{oid}=$rec->{id};
  return $rec;
}

1;
