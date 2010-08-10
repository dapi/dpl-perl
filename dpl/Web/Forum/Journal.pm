package dpl::Web::Forum::Journal;
use strict;
use dpl::Context;
use dpl::System;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Web::Forum::Base;
use dpl::Web::Forum::Topic;
use dpl::Error;
use Exporter;
use base qw(Exporter);
use vars qw(@ISA
            @EXPORT);

@ISA = qw(Exporter
          dpl::Web::Forum::Base);

@EXPORT = qw(LoadJournal
             JournalInstance
             LinkTopic
             UnlinkTopic);

sub JournalInstance {
  my ($id) = @_;
  my $data = ref($id) ? $id : LoadJournal($id);
  return undef unless $data;
  my $class = $data->{class} || 'dpl::Web::Forum::Journal';#$self->classJournal();
  #  print STDERR "JournalInstance: $class\n";
  return $class->instance($data);
}

sub processor {
  'journal';
}

sub LoadJournal {
  my ($id) = @_;
  $id+=0;
  my $res =
    db()->SuperSelectAndFetch(qq(select journal.*, fuser.name as author
                        from journal
                        left join fuser on fuser.id=journal.user_id
                        where journal.id=?),
                                     $id) || return undef;
#   $res->{category_list}=table('topic_category')->List({journal_id=>$res->{id}});
#   if ($res->{category_list} && @{$res->{category_list}}) {
#     push @{$res->{category_list}},{id=>0,name=>'Все'};
#   }
  return $res;
}


# sub MarkAsReadIssue {
#   my ($self,$issue_id,$topics) = @_;
#   return undef unless getUser();
#   my $issue = table('journal_issue')->Load($issue_id) || fatal("No such issue $issue_id");
#   my $uid = getUser()->Get('id');
#   my @t = split(',',$topics);
#   db()->Begin();
#   foreach my $tid (@t) {
#     next unless $tid;
#     my $t = TopicInstance($tid);
#     $t->LockTopic();
#     $t->_clearUserViewInfo($t->Get(),$uid);
#   }
#   db()->Commit();
# #   db()->Query("insert into topic_views (last_view_comment_id, last_posted_comment_id, last_view_file_id, topic_id, user_id) values (?,?,?,?,?)",
# #                      $topic->{last_comment_id},
# #                      $topic->{last_comment_id},
# #                      $topic->{last_file_id},
# #                      $self->Get('id'),$uid);
# 
# }


sub classTopic {'dpl::Web::Forum::Topic'}

sub GetCategories {
  my $self = shift;
  return table('topic_category')->List({journal_id=>$self->Get('id')});
}

sub init {
  my ($self,$data) = @_;
  #  print STDERR "init $self\n";
#  $self->{files_holder}=$forum->{files_holder};
#  db() = $forum->{db};
  $self->{data} = $data;
  $self->{id} = $data->{id};
  $self->{topics}={};
  
  my $m = db()->SuperSelectAndFetchAll("select user_id, journal_members.timestamp, $dpl::Web::Forum::user_fields from journal_members left join fuser on journal_members.user_id=fuser.id where journal_id=?",$data->{id});
  my %members;
  foreach (@$m) {
    $members{$_->{user_id}}=$_;
  }
  $self->{members_list}=$m;
  $self->{members}=\%members;
  return $self;
}

sub AddMember {
  my ($self,$login) = @_;
  my $user = db()->SuperSelectAndFetch('select * from fuser where login=?',$login);
  fatal("No such user '$login'") unless $user;
  db()->
    Query("insert into journal_members (journal_id,user_id,added_user_id) values (?,?,?)",
          $self->{id},
          $user->{id},
          getUser()->Get('id')
         );
}

sub DeleteMember {
  my ($self,$uid) = @_;
  db()->
    Query("delete from journal_members where journal_id=? and user_id=?",
          $self->{id},
          $uid);
}

sub MembersList {
  my $self = shift;
  return $self->{members_list};
}

sub UpdateLastViewInfo {
  my $self = shift;
  return undef unless getUser();
  my $uid = getUser()->Get('id');
  my $rec = db()->SuperSelectAndFetch("select * from journal_views where journal_id=? and user_id=?",
                   $self->Get('id'),$uid);
  if ($rec) {
    db()->Query("update journal_views set new_topics=0, last_topic_time=? where journal_id=? and user_id=?",
          $self->Get('last_topic_time') || $self->Get('changed_time'),$self->Get('id'),$uid);
  } else {
    db()->Query("insert into journal_views (new_topics,last_topic_time,journal_id,user_id) values (0,?,?,?)",
          $self->Get('last_topic_time') || '2006-01-01',$self->Get('id'),$uid);
  }
}

# Акция просмотра журнала (список топиков)

sub IsTopicLinked {
  my ($self,$tid) = @_;
  return db()->
    SuperSelectAndFetch("select * from journal_topic where topic_id=? and journal_id=?",
                        $tid,$self->Get('id'));
}


sub LinkTopic {
  my ($self,$tid) = @_;
  my $jid;

  my $topic = db()->
    SuperSelectAndFetch('select * from topic where id=? for update',$tid);
  die "Can not link remove topic"
    if $topic->{is_removed};
  if (ref($self)) {
    $jid=$self->Get('id');
  } else {
    $jid=$self;
  }
  return undef
    if db()->SuperSelectAndFetch("select * from journal_topic where topic_id=? and journal_id=?",
                                 $tid,$jid);

  my $image_id;
  if ($self->Get('images')) {
    my $res = db()->SuperSelectAndFetch("select * from filseholder_file where topic_id=? and type='image' limit 1",
                                        $self->Get('id'));
    $image_id=$res->{id};
  }
  db()->Query("insert into journal_topic (journal_id,topic_id,image_id) values (?,?,?)",
              $jid, $tid,$image_id);
  
  if ($topic->{journal_id}) {
    db()->Query('update topic set journals=journals+1 where id=?',$tid);
  } else {
    db()->Query('update topic set journals=journals+1, journal_id=? where id=?',
                $jid,$tid);
    db()->Query("update fuser set draft_topics = draft_topics - 1 where id=?",
                $topic->{user_id});
    
  }
  db()->Query('update journal set topics=topics+1 where id=?',$jid);
  return 1;
}

sub UnlinkTopic {
  my ($self,$tid) = @_;
  my $jid;
  my $topic = db()->
    SuperSelectAndFetch('select * from topic where id=? for update',$tid);
  if (ref($self)) {
    $jid=$self->Get('id');
  }
  my $list = $jid ?
    db()->
      SuperSelectAndFetchAll("select * from journal_topic where topic_id=? and journal_id=? for update",
                             $tid,$jid)
        : db()->
          SuperSelectAndFetchAll("select * from journal_topic where topic_id=? for update",
                                 $tid);
  return undef unless $list && @$list;
  foreach my $a (@$list) {
    _unlinkTopic($topic,$a->{journal_id});
  }
  # TODO update topic set journal_id=NULL если надо
  return 1;
}

sub _unlinkTopic {
  my ($topic,$jid)=@_;
  my $tid = $topic->{id};
  db()->Query("delete from journal_topic where topic_id=? and journal_id=?",
              $tid,$jid);
  db()->Query('update journal set topics=topics-1 where id=?',$jid);
  
  if ($jid==$topic->{journal_id}) {
    my $res = db()->SuperSelectAndFetch('select * from journal_topic where topic_id=?',
                                        $topic->{id});
    my $new_journal_id = $res ? $res->{journal_id} : undef;
    db()->Query('update topic set journals=journals-1, journal_id=? where id=?',
                $new_journal_id,$tid);
    db()->Query("update fuser set draft_topics = draft_topics + 1 where id=?",
                $topic->{user_id})
      unless $topic->{is_removed};
  } else {
    db()->Query('update topic set journals=journals-1 where id=?',$tid);
  }
}

sub ListTopics {
  my ($self, $h) = @_;
  fatal("Journal's ID is not defined")
    unless $self->{id};
  $h={} unless $h;
  $h->{where}=[] unless $h->{where};
  $h->{bind}=[] unless $h->{bind};
  # раньше было topic_table.journal_id но тогда не показыались линкованные темы
  push @{$h->{where}},"journal_topic.journal_id=?";
  push @{$h->{bind}},$self->{id};
  $h->{topic_link_table}='journal_topic';
  $h->{use_blacks}=1;
#  $h->{db}=db();
  return dpl::Web::Forum::_listTopics($h);
}


sub IsMember {
  my $self = shift;
  my $u = getUser() || return undef;
  my $uid = $u->Get('id');
  return 1 if $self->{members}->{$uid};
  return $self->Get('user_id')==$uid;
}

sub CheckAccess {
  my $self = shift;
  my $access =shift;
  my $topic = shift;
  return $self->GetJournalAccess($access,$topic) || fatal("No journal access $access");
}

sub HasAccess {
  my ($self,$access,$topic) = @_;
  return $self->GetJournalAccess($access,$topic);
}

sub ChangeTopicStatus {
  my ($self,$tid,$h) = @_;
  return undef unless keys %$h;
  my $topic = TopicInstance($tid) || fatal("No such topic $tid");
  $self->CheckAccess("can_change_topic_status");
  
  $h->{image_id}=undef if exists $h->{image_id} && !$h->{image_id};
  db()->Begin();
  my %k;
  # Специфичтный для topic параметры
  foreach (qw(has_igo)) {
	  if (exists $h->{$_}) {
		  $k{$_}=$h->{$_};
		  delete $h->{$_};
    }
  }
  $k{topper_id}=getUser()->Get('id') if $h->{is_on_top};
  #$k{hotter_id}=getUser()->Get('id') if $k{is_hot};

  if (keys %k) {
  table("topic")->
    Modify(\%k,$tid);
  }
  if (keys %$h) {
    $h->{was_top}=1 if $h->{was_top} || $topic->Get('is_on_top');
    $h->{was_hot}=1 if $h->{was_hot} || $topic->Get('is_hot');
    table("journal_topic")->
      Modify($h,
             {journal_id=>$self->Get('id'),
              topic_id=>$tid});
  }
  db()->Commit();
  return $h;
}


sub GetJournalAccess {
  my $self = shift;
  my $key = shift;
  my $topic = shift;
  my %a;
  my $u = getUser() ? getUser()->Get() : undef;
  fatal("No journal is loaded") unless $self->Get('id');
  my $uid = $u ? $u->{id} : undef;
  my $is_admin = $u && (getUser()->HasAccess('admin') || $self->Get('user_id')==$uid);

  # Может изменять параметры и настройки журнала
  $a{can_edit} = $is_admin;

  # Может изменять статус топика - top,bold,red,sticky
  $a{can_change_topic_status} = $is_admin
		|| ($u && getUser()->HasAccess('advisor'))
			|| $u->{is_academic};

  # Может просматривать журнал;
  $a{can_view} = $is_admin ||
    $self->Get('access_journal')>=4 ||
      ($self->Get('access_journal')>=2 && $u->{level}) ||
        ($self->Get('access_journal')>=3 && $u) ||
          ($self->Get('access_journal')==1 && $self->IsMember());

#  die $self->Get('access_topic');
  $a{can_create_topic} = $is_admin ||
   !$u->{block_type} && (
    $self->Get('access_topic')>=4 ||
      ($self->Get('access_topic')>=3 && $u) ||
#        ($self->Get('access_topic')>=2 && $u->{level}) ||
          ($self->Get('access_topic')>=1 && $self->IsMember())
	  );

  $a{can_comment} = $is_admin ||
    $self->Get('access_comment')>=4 ||
      ($self->Get('access_comment')>=3 && $u) ||
 #       ($self->Get('access_comment')>=2 && $u->{level}) ||
          ($self->Get('access_comment')==1 && $self->IsMember());


  $a{has_any_topic_admin} = $a{can_change_topic_status} || $a{can_delete};

  return $key ? $a{$key} : \%a;
}



sub Edit {
  my ($self,$data) = @_;
  $self->CheckAccess('can_edit');
  map {exists $data->{$_} ? $data->{$_}+=0 : ''} qw(comment_list_mode access_journal access_topic access_comment access_topic_status);
  my $res = table('journal')->Modify($data,$self->Get('id'));
  db()->Commit();
}




=pod

  use dpl::Web::Forum;

my $journal = journal(1);
my $topic = $journal->topic(12);

OR

  my $topic = topic(1,12); # Load 12 topic in 1 journal

OR

  my $topic = topic(12); # Load 12 topic and auto load journal

my $messages = $topic->GetMessagesTree();

=cut
