package dpl::Web::Session::JustUser;
use strict;
use Digest::MD5;
use CGI::Cookie;
use dpl::Context;
use dpl::System;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Web::Session;
use dpl::Web::Utils;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Session);

# В этом модуле в качестве таблицы сессии используется таблица пользовалей
# То есть таблца session неиспользуется вообще

sub GetUserID {
  my $self = shift;
  return $self->Get('id');
}

# Специально для DoLogin, убираем параметры

sub Create {
  my ($self,$data) =  @_;
  $self->GenerateNew();
  $data->{last_ip}=setting('uri')->{remote_ip};
  $data->{session}=$self->{session}
    unless exists $data->{session};
#  $self->{id}=$self->{table}->
#    Create($data)->{id};
#  db()->Commit();
}

#sub GetTableName { 'user'; }
sub GetSQLTableName { $_[0]->GetTableName(); }

sub UpdateUsersLastTime {
  my $self = shift;
  my $ut = $self->GetSQLTableName();
  db()->Query("update $ut set lasttime=now() where id=$self->{id}");
}

sub init {
  my ($self,$cookies,$ssid,$table_name) = @_;
  $self->{table_name}=$table_name || $self->GetTableName();
  $self->{table}=table($self->GetTableName());
  if ($ssid) {
    if ($self->{table}->Load({session=>$ssid})) {
      $self->{id}=$self->{table}->id();
      $self->{is_session_new} = 1;
    }
    $self->{session}=$ssid;
  } elsif (ref($cookies) &&
           $cookies->{$self->cookieName()} &&
           $cookies->{$self->cookieName()}->value()) {
    my $value = $cookies->{$self->cookieName()}->value();
    if ($self->{table}->Load({session=>$value})) {
      $self->{id}=$self->{table}->id();
    }
    $self->{session}=substr($cookies->{$self->cookieName()}->value(),0,32);
  } else {
    $self->GenerateNew();
  }
  if ($self->{id}) {
    if ($self->Login()) {
      $self->UpdateUsersLastTime();
    } else {
      $self->{table}->clear();
      $self->{id}=undef;
    }
  }
  $self->LogSession();
  db()->Commit();
  return $self;
}

sub LogSession {
#  die 1;
}

sub Load {
  my ($self,$ssid) = @_;
  $self->{table}->Load({session=>$ssid});
}

sub Modify {
  my ($self,$data) = @_;
#  print STDERR "-- Modify\n";
  return undef unless $data;
  $self->{table}->
    Modify($data,{session=>$self->{session}});
  db()->Commit();
}

# Запускается когда делается login с паролем

sub Login {
  my ($self,$user)=@_;
  $user=$self unless $user;
  $user->Modify({session=>$self->{session},
                 is_logged=>1,
                 sessiontime=>'now()',
                 last_ip=>setting('uri')->{remote_ip},
#                 user_agent=>setting('uri')->{user_agent}
                });
#  print "Login $user->{data}->{id}: $self->{session} \n";
  db()->Commit();
  return 1;
}

1;
