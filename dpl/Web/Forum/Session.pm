package dpl::Web::Forum::Session;
use strict;
#::JustUser
use base qw(dpl::Web::Session::JustUser);
use dpl::Context;
use dpl::Db::Database;
use dpl::Error;

# sub Create {
#   my ($self,$data) =  @_;
#   $self->GenerateNew();
#   $data->{last_ip}=setting('uri')->{remote_ip};
#   $data->{user_agent}=setting('uri')->{user_agent};
#   $data->{session}=$self->{session}
#     unless exists $data->{session};
# }

sub Login {
  my ($self,$user)=@_;
  
  $user=$self unless $user;
  if ($self->{table}->get('block_type')>=10 ||
      $self->{table}->get('is_removed')) {
    fatal("No access.",$self->{table}->get('block_comment'),',',$self->{table}->get('block_type'));
  }
  $user->Modify({session=>$self->{session},
                 is_logged=>1,
                 sessiontime=>'now()',
                 last_ip=>setting('uri')->{remote_ip},
                 user_agent=>setting('uri')->{user_agent}
                });
#  print STDERR "Login $user, $user->{data}->{id}: $self->{session} \n";
  db()->Commit();
  return 1;
}
# 
# 
# sub UpdateUsersLastTime {
#   my $self = shift;
#   my $user = $self->{table};
#   die $user->get('block_type');
#   fatal("No access for user. Cause: ".$user->get('block_comment'))
#     if $user->get('block_type')>=10;
#   my $ut = $self->GetSQLTableName();
#   db()->Query("update $ut set lasttime=now() where id=$self->{id}");
# }

# 
# sub Login {
#   my ($self,$user)=@_;
#   $self->Modify({id=>$user->Get('id'),
#                  last_ip=>setting('uri')->{remote_ip},
#                  user_agent=>setting('uri')->{user_agent}});
#   db()->Commit();
#   return 1;
# }

1;
