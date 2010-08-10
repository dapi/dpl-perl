package dpl2::Web::Session;
use strict;
use CGI::Cookie;
use Digest::MD5;
use dpl::Db::Table;



# Установки

sub sessionField { 'session'; }
sub cookieName { 'session'; }
sub expires { '+120d'; }
sub dbTable { table('session'); }



# Выполняется в конце процесса, чтобы сохранить
# данные о новой сесии в базу

sub SaveSession {
  my $self = shift;

  return $self->{table}->
    Create($self->{rec})
      if $self->IsSessionNew();

  return $self->{table}->
    Modify($self->{rec},
           {$self->sessionField()=
            >$self->{old_ssid}})
      if $self->IsSessionModified();

  return undef;
}


# Журналирование информации о сессии
# Можно внести запись в журнал
# или произвести изменения в сессии

sub LogSession {
  my $self = shift;
  my $is_new = shift;
  # При желании внести изменения в куку - её нужно создать или изменить на самом деле
}

sub LoadSession {
  my ($self,$ssid) = @_;
  $self->{rec} = $self->{table}->Load({session=>$self->sessionField()});
}

sub InitSession {
  my $self = shift;
  # Если сессия загружена - произвести журналирование
  $self->{table} = $self->dbTable();
  if ($self->LoadSession($self->{params}->{ssid})
      || $self->LoadSession($self->{cookie}->{ssid})) {
    $self->LogSession();
  } else {
    $self->GenerateSession();
    $self->LogSession(1);
  }
}



sub GetCookieToSet {
  my ($self) = @_;
  return $self->{cookie_to_set};
}


sub GenerateSession {
  my $self = shift;
  my %rec = (ssid=>$self->generate(),
             ip=>setting('uri')->{remote_ip});
  $self->{is_new}=1;
  $self->{cookie_to_set} =
    new CGI::Cookie(-name=>$self->cookieName(),
                    -expires => $self->expires(),
                    -value=>$self->{rec}->{ssid});
}

sub IsSessionNew {
  return $_[0]->{is_new};
}

sub IsSessionModified {
  return $_[0]->{is_modified};
}

sub generate {
  my $length = shift;
  $length=64 unless $length>0;
  return substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0,
                $length);
}


1;
