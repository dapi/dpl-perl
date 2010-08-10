package dpl::Web::Processor::Login;
use strict;
use dpl::Error;
use dpl::XML;
use dpl::Log;
use dpl::Db::Database;
use dpl::Context;
use dpl::Web::Processor::Session;
use base qw(dpl::Web::Processor::Session);
sub lookup {1;}

sub LoadUser {
  my $self = shift;
  my $res = $self->SUPER::LoadUser(@_);
  setContext('access',$self->user()->GetAccesses())
    if $self->user()->IsLoaded();
  return 1;
}


sub ACTION_default {
  my $self = shift;
  my $p = setting('uri')->{page_path};
  if ($p eq 'login') {
    return $self->ACTION_login($p);
  } elsif ($p eq 'logout') {
    return $self->ACTION_logout($p);
  } else {
    fatal("no such action: default");
  }
}

sub ACTION_login {
  my $self = shift;
#  die 1;
  if ($self->param('ssid')) {
 #   die 1;
    fatal("Не должно быть инициализированной сессии")
      if $self->{session};
    $self->session(); # сегерируем $self->{session}
    return $self->SUBACTION_login()
      if $self->user()->
        Load($self->{session}->GetUserID());
  } else {
    my ($login,$password)=(lc($self->param('login')),
                           $self->param('password'));
    my $res = $self->user()->LoadByLogin($login,$password);

    if ($res) {
      #      $self->session(); # сегерируем $self->{session}
#      die $self->session().'';
      $self->session()->Login($self->user());
      # Вырубил за ненадобностью
      #      $self->DoLogin($res);
      return $self->SUBACTION_login();
    }
#    die 3;
    $self->{wrong_password}=1 if defined $res;
    setContext('login',$login);
  }
  return $self->SUBACTION_no_login();
}


sub DoLogin {
  my ($self,$new_uid) = @_;
  $self->session()->Create();
  db()->Commit();
}


# Что-то неработает такая штука
#
# sub DoLogin {
#   my ($self,$new_uid) = @_;
#   my $uid = $self->session()->GetUserID();
# #  die "$uid";
#   if ($uid) {
#     $self->{session}->Create({user_id=>$new_uid});
#   } else {
#     $self->{session}->Modify({user_id=>$new_uid});
#   }
#   # TODO
#   #   my $sid = $self->{session}->id();
#   #   $self->CopySessionBasketToUser($sid,$res->{id});
#   db()->Commit();
# }

# sub ACCESS_login {
#   my $self = shift;
#   die 33;
#   setContext('user',$self->user()->Get());
#   return "";
# }
#
sub SUBACTION_no_login {
  my $self = shift;
  $self->template('no_login');
}

sub ACTION_remember {
  #  die 'TODO: напоминатель пока не работает';
  die 'not implemented';
  return 1;
}

sub ACTION_logout {
  my $self = shift;
  setContext('user',undef);
  $self->session()->Create({});
  return "";
}


1;
