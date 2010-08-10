package dpl::Db::Table;
use strict;
use Data::Dumper;
use dpl::XML;
use dpl::Error;
use dpl::Context;
use dpl::Log;
use dpl::Config;
use dpl::Base;
use dpl::Db::Database;
use dpl::Db::Filter;
use strict;
use vars qw(@EXPORT
	    @ISA);

@EXPORT = qw(table);

@ISA = qw(Exporter
	  dpl::Base);

#@odb::Error::Table::ISA = qw(odb::Error);
sub fatal  { die join(',',@_); };
# Иначе не показыват строку в вебе
#sub fatal  { throw dpl::Error(-text=>@_); }

sub table {
  my $name = shift;
  return dpl::Db::Table->instance($name);

  #  return context('tables',
  #		 $name) || setContext('tables',$name,
  #                                      dpl::Db::Table->instance($name));
}

sub init {
  my ($self) = @_;
  my $name = $self->{name};

  my $conf = config()->root();

  my $node = $conf->findnodes("./tables/table[\@name='$name']")->pop()
    || fatal("No config node for table: $name");
  $self->{node} = $node;
  $self->{table} = xmlDecode($node->getAttribute('table'))
    if $node->hasAttribute('table');
  if (my $on = $node->findnodes('./order')->pop()) {
    $self->{order} = xmlDecode($on->textContent());
  }
  my %serializers;
  foreach ($node->findnodes("./attributes/serializer")) {
    my $name = xmlDecode($_->getAttribute('name'));
    my $attr = xmlAttrToHash($_);
    #    fatal("Сериализатор может быть только символьным типом")
    #      unless $attr->{type} eq 'char';
    $attr->{filter} = dpl::Db::Filter::filter($attr->{type}) if $attr->{type};
    $attr->{attrs}={};
    $serializers{$name}=$attr;
  }
  my %attributes;
  my %constraints;
  my $id;
  foreach ($node->findnodes("./attributes/attr|./attributes/serializer/attr|./attributes/id")) {
    my $name = xmlDecode($_->getAttribute('name'));
    my $attr = xmlAttrToHash($_);
    my %const;
    $const{unique}=1
      if $attr->{unique};
    $const{notnull}=1
      if $attr->{notnull};
    if ($_->nodeName() eq 'id') {
      fatal("Dupicate ID attribute: $name") if defined $self->{id};
      $self->{id}=$name;
      $self->{id_seq}=xmlDecode($_->getAttribute('sequence'))
        if $_->hasAttribute('sequence');
      $self->{id_increment}=$_->hasAttribute('increment') ?
        xmlDecode($_->getAttribute('increment')) : undef;
    }
    $attr->{filter} = dpl::Db::Filter::filter($attr->{type}) if $attr->{type};
    my $parent = $_->parentNode();
    if ($parent->nodeName() eq 'serializer') {
      my $s = xmlDecode($parent->getAttribute('name'));
      $attr->{serializer}=$s;
      $serializers{$s}->{attrs}->{$name}=$attr;
    }
    $attributes{$name}=$attr;
    $constraints{$name}=\%const
      if %const;
  }
  $self->{db}=db($node->hasAttribute('db') ? xmlDecode($node->getAttribute('db')) : '');
  $self->{sers} = \%serializers;
  $self->{attr} = \%attributes;
  $self->{constr} = \%constraints;
  return $self;
}

sub id {
  my $self = shift;
  fatal("Unknown id name") unless $self->{id};
  return $self->get($self->{id});
}

sub idname {
  my $self = shift;
  return $self->{id};
}

# params:
#   table - sql table name
#   attr  - hash of attributes type
#   order - sql order string
#   id    - sql table id field name


sub DESTROY {
  my $self=shift;
  $self->finish();
}

sub name { return $_[0]->{name}; }

sub tableName { return $_[0]->{table}; }

sub checkConstraints {
  my ($self,$data,$id,$where) = @_;
  my $c = $self->{constr};
  return undef unless %$data || %$c;
  my %notnull;
  my %unique;
  foreach my $k (keys %{$self->{attr}}) {
    my $v = $self->{attr}->{$k};
    if (exists $data->{$k}) {
      $unique{$k} = $data->{$k} if $v->{unique};
      $data->{$k} = substr($data->{$k},0,$v->{length})
        if $v->{length} && length($data->{$k})>$v->{length};
      $notnull{$k}=1 if $v->{notnull} && !($data->{$k} || length($data->{$k}));
    } elsif ($v->{notnull}) {
      next if $id;
      $notnull{$k}=1;
    }
  }
  my %res;
  $res{notnull}=\%notnull
    if %notnull;
  my %allu;
  if (%unique) {
    my %u;
    my $w = {or=>\%unique};
    $w = {and=>[$w,"$self->{id}<>$id"]}
      if defined $id;
    $w = {and=>[$w,$where]}
      if defined $where;
    my $sth = $self->{db}->Select($self->{table},'*',$w) || $self->error(30);
    while (my $a=$self->{db}->Fetch($sth)) {
      my $f  = $self->FromSQL($a);
      my %r;
      foreach (keys %unique) {
        $r{$_}=1 if $f->{$_} eq $unique{$_};
      }
      logger()->
        warning("При проверке на уникальность не найдено ни одного совпадения")
          unless %r;
      %allu=(%allu,%r);
    }
    $sth->finish();
  }
  $res{unique}=\%allu if %allu;
  return undef unless %res;
  $res{all}={};
  map {$res{all}->{$_}='unique'} keys %allu;
  map {$res{all}->{$_}='notnull'} keys %notnull;
  return \%res;
}

sub Load {
  my ($self,$param,$filter)=@_;
  $self->error("No where to load table")
    unless defined $param;
  $param={$self->{id}=>$param}
    if !ref($param);
  my $res = $self->Select('*',$param,$self->prepareOrder());
  return undef unless $res;
  return $self->getOne($filter);
}

sub clear {
  my $self=shift;
  $self->finish();
  $self->{list}=undef;
  $self->{hashlist}=undef;
}

sub List {
  my ($self,$param,$count)=@_;
  return $self->Select('*',$param,$self->prepareOrder()) ? $self->getList($count) : undef;
}

sub HashList {
  my ($self,$param,$key)=@_;
  return $self->Select('*',$param,$self->prepareOrder()) ? $self->getHashList($key) : undef;
}

sub Modify {
  my ($self,$data,$where,$filter)=@_;
  unless ($where) {
    my $hr=$self->get();
    $self->error("Не указан id для модификации")
      unless $hr && defined $hr->{$self->{id}};
    $where={$self->{id}=>$hr->{$self->{id}}};
  }
  $where={$self->{id}=>$where}
    unless ref($where);
  $data=$self->ToSQL($data,$filter)
    if ref($data)=~/HASH/;
  my $res = $self->{db}->Update($self->{table},$data,$self->prepareWhere($where));
  return $res if !$res || $res eq '0E0';
  if ($self->{list}) {
    foreach (keys %$data) {
      $self->{list}->[0]->{$_}=$data->{$_};
    }
  }
  return 1;
}

sub Create {
  my ($self,$data,$filter)=@_;
#  $data->{$self->{id}}=$self->{db}->GenerateId($self->{table})
  #    if $self->{id} && $self->{use_generator} && not exists $data->{$self->{id}};
  $data=$self->ToSQL($data,$filter)
    if ref($data)=~/HASH/;
  $self->clear();
  my $res=$self->{db}->Insert($self->{table},$data);
  return undef
    unless $res;
  $data->{$self->{id}}=
    $self->{db}->GetLastIncrement($self->{table},$self->{id},$self->{id_seq})
      if $self->{id_increment} eq 'auto' && !exists $data->{$self->{id}};
  $self->{list}=[];
  $self->{hashlist}={};
  return $self->{list}->[0]=$data;
}

sub Replace {
  my ($self,$data,$filter)=@_;
  # $data->{$self->{id}}=$self->{db}->GenerateId($self->{table})
  #   if $self->{id} && $self->{use_generator} && not exists $data->{$self->{id}};
  $data=$self->ToSQL($data,$filter)
    if ref($data)=~/HASH/;
  $self->clear();
  my $res=$self->{db}->Replace($self->{table},$data);
  return undef
    unless $res;
  $data->{$self->{id}}=
    $self->{db}->GetLastIncrement($self->{table},$self->{id},$self->{id_seq})
      if $self->{id_increment} eq 'auto' && !exists $data->{$self->{id}};
  $self->{list}=[];
  $self->{hashlist}={};
  return $self->{list}->[0]=$data;
}


sub Delete {
  my ($self,$where)=@_;
  if ($where=~/^\d+$/ && $self->{id}) {
    $where={$self->{id}=>$where};
  } elsif (!$where) {
    my $hr=$self->get();
    $self->error("No WHERE for delete")
      unless $hr && defined $hr->{$self->{id}};
    $where={$self->{id}=>$hr->{$self->{id}}};
  }
  return $self->{db}->Delete($self->{table},$self->prepareWhere($where));
}

sub prepareOrder {
  my $self=shift;
  return "order by $self->{order}" if $self->{order};
}

sub prepareWhere {
  my ($self,$data,$filter)=@_;
  if (ref($data)=~/HASH/) {
    return $self->ToSQL($data,$filter,1);
  } elsif (ref($data)=~/ARRAY/) {
    foreach (@$data) {
      $_=$self->prepareWhere($_,$filter);
    }
    # Вставил строку так как не срабатывало при Delete
    return join(' and ',@$data);
  } else {
    return $data;
  }
}


sub Select {
  my $self=shift;
  $_[1]=$self->ToSQL($_[1]) if @_>1 && ref($_[1])=~/HASH/;
#  die Dumper($_[1]) if $self->{table} eq  'router';
  $self->{sth} = $self->{db}->Select($self->{table},@_ ? @_ : '') || $self->error(30);
  $self->{list}=[];
  $self->{hashlist}={};
  return $self->{sth};
}

sub SelectAll {
  my ($self,$data,$filter)=@_;
  $self->Select('*',$data,$self->prepareOrder());
  return $self->getList(0,$filter);
}

sub SelectOne {
  my ($self,$data,$filter)=@_;
  $self->Select('*',$data);
  return $self->getOne($filter);
}

sub count {
  my $self=shift;
  my $list = $self->getList();
  return $list ? scalar @{$self->getList()} : undef;
}

sub getOne {
  my ($self,$key,$filter) = @_;
  $filter={$key=>$filter} if $key && !ref($filter);
  my $hr=$self->get($key,$filter);
  $self->finish();
  return $hr;
}

sub get {
  my ($self,$key,$filter)=@_;
  my $hr=$self->getList(1,$filter);
  return undef unless $hr;
  my $data = $key ? $hr->[0]->{$key} : $hr->[0];
  return $data;
}

sub getHashList {
  my $self=shift;
  my $key = shift || $self->{id};
  if ($self->{sth}) {
    my $c=0;
    while (my $a=$self->{db}->Fetch($self->{sth})) {
      my $f=$self->FromSQL($a);
      push @{$self->{list}},$f;
      $self->{hashlist}->
	{$f->{$key}}=$f;
    }
    $self->finish();
  }
  return $self->{hashlist};
}

sub getList {
  my ($self,$count) = @_;
  if ($self->{sth}) {
    my $c=0;
    while (my $a=$self->{db}->Fetch($self->{sth})) {
      $c++;
      my $f=$self->FromSQL($a);
      push @{$self->{list}},$f;
      $self->{hashlist}->{$f->{$self->{id}}}=$f
	if $self->{id};
      last if $count && $c>=$count;
    }
    $self->finish();
    #unless $count;
  }
  return $self->{list};
}

sub FromSQL {
  my ($self,$data)=@_;
  foreach (keys %$data) {
    if ($self->{sers}->{$_}) {
      my $h = $self->{sers}->{$_}->{filter}->FromSQL($data->{$_},$_,$data);
      foreach (keys %{$self->{sers}->{$_}->{attrs}}) {
        $data->{$_}=$h->{$_};
      }
    } elsif ($self->{attr}->{$_}->{filter}) {
      $data->{$_} = $self->{attr}->{$_}->{filter}->FromSQL($data->{$_},$_,$data);
    }
  }
  return $data;
}

sub ToSQL {
  my ($self,$dat,$is_where)=@_;
  my %sers;
  if (ref($dat)=~/array/i) {
    foreach (0..$#$dat) {
      $dat->[$_]=$self->ToSQL($dat->[$_],$is_where);
    }
    return $dat;
  } elsif (ref($dat)=~/hash/i) {
    my %data=%$dat;
    foreach (keys %data) {
      if (exists $self->{attr}->{$_}) {
      if ($self->{attr}->{$_}->{serializer}) {
        my $n=$self->{attr}->{$_}->{serializer};
        $sers{$n}=[] unless $sers{$n};
        push @{$sers{$n}},$_;
      } elsif ($self->{attr}->{$_}->{filter}) {
        $data{$_} = $self->{attr}->{$_}->{filter}->ToSQL($data{$_},$_,\%data);
      } else {
        logger()->debug("Столбец $_ таблицы $self->{table} не имеет описания");
      }
    } elsif (ref($data{$_})=~/HASH/i || ref($data{$_})=~/ARRAY/i) {
      $data{$_}=$self->ToSQL($data{$_},$is_where);
    } else {
      next;
    }
  }
  foreach (keys %sers) {
    my %h;
    foreach (@{$sers{$_}}) {
      $h{$_}=$data{$_};
      delete $data{$_};
    }
    $data{$_}=$self->{sers}->{$_}->{filter}->ToSQL(\%h,$_,\%data);
  }
    #  print Dumper(\%data);
    return \%data;

  } else {
    return $dat;
  }
}

sub finish {
  my $self=shift;
  return undef unless $self->{sth};
  $self->{sth}->finish();
  $self->{sth}=undef;
}

1;
