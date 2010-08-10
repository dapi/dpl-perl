package dpl::Web::Session;
use strict;
use Digest::MD5;
use CGI::Cookie;
use dpl::Context;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Base;
use dpl::Web::Utils;
use dpl::XML;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);


sub GetUserID {
  my $self = shift;
  return $self->Get('user_id');
}

sub GetTableName { $_[0]->{table_name} || 'session'; }

sub generate {
  my $length = shift;
  $length=32 unless $length>0;
  return substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0,
                $length);
}

# sub LoadUser {
#   my ($self,$sid) = @_;
#   user()->Load($self->GetUserID());
# #  $self->UpdateUsersLastTime();
# }

sub init {
  my ($self,$cookies,$ssid,$table_name) = @_;
  $self->{table_name}=$table_name || $self->GetTableName();
  $self->{table}=table($self->GetTableName());
  if ($ssid) {
    if ($self->{table}->Load({session=>$ssid})) {
      $self->{id}=$self->{table}->id();
      $self->{is_session_new} = 1;
      return $self;
    }
  } elsif (ref($cookies)) {
#    die 123;
    if ($cookies->{$self->cookieName()} &&
        $self->{table}->Load({session=>$cookies->{session}->value()})) {
      $self->{id}=$self->{table}->id();
#      $self->LoadUser($self->{id}=$self->{table}->id());
      return $self;
    }
    # print STDERR "EXISTS SESSION $self->{data}->{session}\n";

  } elsif ($cookies) {
    # use as ssid
    if ($self->{table}->Load({session=>$cookies})) {
      $self->{id}=$self->{table}->id();
#      $self->LoadUser($self->{id}=$self->{table}->id());
      return $self;
    }
  }
  $self->Create({});
  return $self;
}

sub Login {
  my ($self,$user)=@_;
  $self->Modify({user_id=>$user->Get('id'),
                 ip=>setting('uri')->{remote_ip}});
  db()->Commit();
  return 1;
}


sub Load {
  my ($self,$ssid) = @_;
  $self->{table}->Load({session=>$ssid});
}

sub Modify {
  my ($self,$data) = @_;
  return undef unless $data;
  $self->{table}->
    Modify($data,$self->{id});
  db()->Commit();
}

sub Get {
  my $self = shift;
  return $self->{table}->get(@_);
}

sub cookieName {  'session'; }

sub GetCookie {
  my ($self) = @_;
  my $domain = setting('uri')->{current}->hostname();
  my $path = setting('uri')->{home};
  $path=~s/http:\/\/$domain//;
#  die "$domain $path";
#  die "$domain";
  return new CGI::Cookie(-name=>$self->cookieName(),
                         -value=>$self->{session},
                         -expires => '+120d',
 #                        -domain=>$domain,
#                         -path=>$path,
                         # -secure=>1
                        ) if $self->{is_session_new};
}

sub GenerateNew {
  my $self = shift;
  $self->{is_session_new} = 1;
  $self->{session} = generate();
}

sub Create {
  my ($self,$data) =  @_;
  $self->GenerateNew();
  $data->{ip}=setting('uri')->{remote_ip};
  $data->{session}=$self->{session}
    unless exists $data->{session};
  $self->{id}=
    $self->{table}->
      Create($data)->{id};
  db()->Commit();
}

sub id {
  my $self = shift;
  return $self->{id};
}

1;
