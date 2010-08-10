package dpl::Web::Processor::Session;
use strict;
use Exporter;
use dpl::Web::User;
use dpl::Context;
use dpl::Web::Session::JustUser;
use dpl::Web::Processor::Db;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Processor::Db);


# Возаращает устанавливаемые куки
sub getCookies {
  my $self = shift;
  $self->addCookie($self->{session}->GetCookie())
    if $self->{session};
  return $self->SUPER::getCookies();
}

sub GetUserID { $_[0]->Get('user_id'); }

sub sessionModule { 'dpl::Web::Session::JustUser'; }

sub cookieName { 'ssid'; }

sub sessionTableName { undef; }

sub session {
  my $self = shift;
  return $self->{session} if exists $self->{session};
  # TODO испольование ssid должно регулироваться в конфиге
  my $s = $self->param($self->cookieName());
  $self->{session}=$self->sessionModule()->
    instance('session',
             $self->cookies(),
             $s,
             $self->sessionTableName());
  return $self->{session};
}

sub userModule { 'dpl::Web::User'; }

sub userTableName { undef; }

sub user {
  my $self = shift;
  return $self->{user} if exists $self->{user};
  my $user=$self->userModule()->
    instance('user',$self->userTableName())
      || $self->fatal("Can't init user class");
  return $self->{user}=$user;
}

sub LoadUser {
  my $self = shift;
  my $uid = $self->session()->GetUserID();
#  die "$uid";
  return undef unless $uid;
  my $user = $self->user();

  # Не работает с ипотекой
  #  $user->setUsersTable($self->session()->{table});

  return undef unless $user->Load($uid);
  setUser($user);
  setContext('user',$user->Get());
  return 1;
}

1;
