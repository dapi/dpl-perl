package dpl::Web::Processor::CGI;
use strict;
use Exporter;
use CGI;
use CGI::Cookie;
use dpl::Web::Processor;
use dpl::Context;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Processor);

sub cookies {
  my $self = shift;
  my %cookies = fetch CGI::Cookie;
  return \%cookies;
}

sub cgi {
  my $self = shift;
  return $self->{cgi}||=CGI->new;
}

sub param {
  my $self = shift;
  return @_ ? $self->cgi()->param(@_) : $self->cgi()->param();
}


sub CheckParams {
  my $self = shift;
  my $h = $self->GetParams(@_);
  my $f = context('fields');
  setContext('fields',$f ? {%$f,%$h} : $h);
  # empty - не все поля заполненны
  # password - не верный пароль
  # exists - такой логин уже существует
  my (%e,%f);

  foreach (@_) {
    unless (defined $h->{$_} && $h->{$_} ne '') {
      $e{empty}=1;
      $f{$_}=1;
    }
  }
  setContext('bad_fields',\%f);
  setContext('errors',\%e);
  return undef if keys %f || keys %e;
  return $h;
}

sub GetParams {
  my $self = shift;
  my %p = map {$_=>1} @_;
  my %h;
  foreach ($self->param()) {
    $h{$_}=$self->param($_)
      if exists $p{$_}
    }
  return \%h;
}

sub NotExists {
  my ($self,$h) = (shift,shift);
  my $e = ref($_[0])=~/HASH/i ? shift : {};
  foreach (@_) {
    $self->AddError($e,$_,'notexists')
      unless exists $h->{$_} && $h->{$_} ne '';
  }
  return %$e ? $e : undef;
}

sub AddError {
  my ($self,$el,$field,$error) = @_;
  $el->{list}=[] unless exists $el->{list};
  $el->{fields}={} unless exists $el->{fields};
  $el->{fields}->{$field}=$error;
  push @{$el->{list}},
    {field=>$field,
     error=>$error};
}

sub EXAMPLE_edit {
  my ($self) = @_;
  my $id = $self->param('id');
  my $h = $self->
    GetParams(qw(field list));
  my $rec = $self->LoadRecord($id);
  setContext('fields',{%$rec,%$h});
  return $rec
    unless $self->param('submit');
  return $rec
    if setContext('errors',
               $self->NotExists(qw(unique list)));
  my $res = $self->ModifyRecord($h,$id);#table('demand_order')->Modify($h,$id);
  db()->Commit();
  return 'redirect to list';
  #  return 'demands/connects/';
}



1;
