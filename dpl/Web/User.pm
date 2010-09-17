package dpl::Web::User;
use strict;
use dpl::Config;
use Digest::MD5;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Context;
use dpl::Base;
use dpl::Error;
use dpl::Log;
use dpl::Web::Utils;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub GetTableName { $_[0]->{table_name} || 'user'; }

sub init {
  my ($self,$table_name) = @_;
  my $config = config()->root();
  my $nodes = $config->findnodes("./user");
  my %accesses;
  $self->{table_name} = $table_name || $self->GetTableName();
  $self->{table}=table($self->GetTableName());
  if ($nodes) {
    my $node = $nodes->pop();
    $self->{node}=$node;
    my $nodes = $node->findnodes("./access");

    foreach (@$nodes) {
      my $name = xmlDecode($_->getAttribute('name'));
      logger()->warn("Duplicate users access: $name")
        if exists $accesses{$name};
      my $a = $_->findnodes("*");
      my %group=();
      foreach my $aa (@$a) {
        my $nodename = $aa->nodeName();
        if ($nodename eq 'user_attribute') {
          $group{user_attribute}=[] unless $group{user_attribute};
          my $attr = xmlDecode($aa->getAttribute('name'));
          push @{$group{user_attribute}}, {key=>$attr,
                                           value=>$aa->textContent()};
        } else {
          $self->fatal("Unknown attribute for users access: $nodename");
        }
      }
      $accesses{$name}=\%group;
    }
  }
  $self->{accesses}=\%accesses;
  return $self;
}

sub loginField { 'login'; }

sub encrypt_password {
  my ($self,$password)=@_;
  return $password;
}

sub searchUser {
  my ($self,$login,$use_email) = @_;
  $login=lc($login);
  $login=~s/\"//; $login=~s/\'//;
  my $f = $self->loginField();
  my $l = lc($login);
  my $res = $self->{table}->Load(["lower($f)='$l'"]);
  ###  my $res = $self->{table}->Load({login=>$login});
  $res = $self->{table}->Load({email=>$login})
    if !$res && $use_email;
  return undef                  # Пользователь ненайден
    unless $res && !$res->{is_removed};
  return $res;
}

sub LoadByLogin {
  my ($self,$login,$password,$use_email) = @_;
  $self->{is_loaded}=0;
  my $res = $self->searchUser($login,$use_email);
  unless ($res->{password} eq $self->encrypt_password($password) || ($res->{auto_password} && ($res->{auto_password} eq $password))) {
    $self->{table}->clear();
    return 0;                   # Неверный пароль
  }
  $self->{is_loaded}=1;
  $self->post_load();
  return $self->{table}->id();
}

sub post_load {};

sub Load {
  my ($self,$uid) = @_;
  $self->{is_loaded}=0;
  unless ($uid) {
    $self->{table}->clear();
    return undef;
  }
  return undef
    unless $self->{table}->Load($uid);
  $self->{is_loaded}=1;
  $self->post_load();
  return $self;
}

sub LoadBy {
  my ($self,$params) = @_;
  $self->{is_loaded}=0;
  unless ($params) {
    $self->{table}->clear();
    return undef;
  }
  return undef
    unless $self->{table}->Load($params);
  $self->{is_loaded}=1;
  $self->post_load();
  return $self;
}


sub Modify {
  my ($self,$data) = @_;
  return undef unless $data;
  #  print STDERR "-- Modify user\n";
#  $data->{email}=lc($data->{email}) if exists $data->{email};
  
  $self->{table}->Modify($data);
  $self->{table}->
    Load($self->{table}->id());
}

sub setUsersTable {
  my ($self,$table) = @_;
  $self->{table}=$table;
  $self->post_load()
    if $self->{is_loaded}=$table->id();

  return $self;
}

sub Get {
  my $self = shift;
  #  fatal("Пользователь не загружен1")
  return undef
    unless $self->IsLoaded();
  return $self->{table}->get(@_);
}

sub GetAccesses {
  my $self = shift;
  my %a;
  foreach (keys %{$self->{accesses}}) {
    $a{$_}=$self->HasAccess($_);
  }
  return \%a;
}

sub HasAccess {
  my ($self,$name) = @_;
  return undef #  fatal("Пользователь не загружен2")
    unless $self->IsLoaded();
  return 1 if $name eq '*';
  fatal("No such users access: $name")
    unless exists $self->{accesses}->{$name};
  my $g = $self->{accesses}->{$name};
#  print STDERR "HasAccess: $name\n";
  if ($g->{user_attribute}) {
    foreach (@{$g->{user_attribute}}) {
      #      print STDERR "Compare ($_->{key}): $_->{value}=".$self->Get($_->{key})."\n";
      return 1 if $_->{value} eq 'true' && $self->Get($_->{key});
      return 1 if $_->{value}=~/\D/ ? $self->Get($_->{key}) eq $_->{value} : $self->Get($_->{key})==$_->{value};
    }
  } else {
    return 1;
  }
#  print STDERR "NO HasAccess: $name\n";
  return 0;
}

sub IsLoaded {
  my $self = shift;
  return $self->{is_loaded};
}

1;
