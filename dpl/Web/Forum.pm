package dpl::Web::Forum;
use strict;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Web::Forum::Journal;
use dpl::Web::Forum::Topic;
use dpl::Web::Session;
use dpl::System;
use dpl::Context;
use dpl::Sendmail;
use URI::Escape;
use HTTP::Lite;
use Text::Iconv;
use Digest::MD5 qw(md5_hex);
use Exporter;
use vars qw(@ISA
            $user_fields
            @EXPORT);
@ISA=qw(Exporter
        dpl::Web::Forum::Base);
@EXPORT=qw(forum);
$user_fields = "fuser.login as login, fuser.email as email, fuser.icon as icon, fuser.mobile_checked as mobile_checked,
fuser.thumb_file, fuser.thumb_width, fuser.thumb_height, fuser.thumb_time,
fuser.level as level, fuser.karma as karma, fuser.is_fotocor as is_fotocor,
fuser.lasttime as lasttime ";

sub forum { setting('forum'); }

sub define {
  my $forum = shift;
  setting('files_holder',$forum->{files_holder} || fatal("no files holder in forum"));
  setting('forum',$forum);

  my $sth = SuperSelect('select * from fuser order by id');
  my %users_by_id;
  my %users_by_login;

  while ($_=$sth->fetchrow_hashref()) {
    $users_by_id{$_->{id}} = $_;
    $users_by_login{$_->{login}} = $_;
  }

  setting('users_by_id',\%users_by_id);
  setting('users_by_login',\%users_by_login);
}

# 
# 
# sub RemoveFileFromGallery {
#   my ($self,$file_id) = @_;
#   db()->
#     SuperSelectAndFetchAll('select * from filesholder_dir where id=2 or id=3 for update');
# 
#   $self->{files_holder}->RemoveLinkOfFileFromDir($file_id,2);
#   $self->{files_holder}->RemoveLinkOfFileFromDir($file_id,3);
# 
#   table('filesholder_file')->
#     Modify({is_in_gallery=>0},
#            $file_id);
# 
#   db()->Commit();
# }
# 
# sub PutFileInGallery {
#   my ($self,$file_id) = @_;
#   my $file = table('filesholder_file')->Load($file_id);
#   unless ($file->{is_in_gallery}) {
#     db()->
#       SuperSelectAndFetchAll('select * from filesholder_dir where id=2 or id=3 for update');
# 
# #    $self->{files_holder}->CreateLink($file_id,2);
# 
#     table('filesholder_file')->
#       Modify({is_in_gallery=>1,
#               is_moderated=>1},
#              $file_id);
# 
#     db()->Commit();
#   }
# }


sub ShortText {
  my $text = shift;
  return $text if length($text)<=250;
  $text=substr($text,0,250);
  $text=~s/\S+$//g;
#  die length($text);
  return $text;
}


sub init {
  my $self = shift;
  my %h = @_;
  $self->{db}=$h{db} || db();# || die 'db is not defined';
  $self->{files_holder}=$h{files_holder};# || die 'files_holder is not defined';
  return $self;
}

sub files_holder {
  my $self = shift;
  return $self->{files_holder} || die 'files_holder is not defined';
}

sub classJournal {'dpl::Web::Forum::Journal'}
sub classUser {'dpl::Web::Forum::User'}


sub GetOpenJournals {
  my $uid = shift;
  return table('journal')->List();
}


sub UserInstance {
  my ($self,$id) = @_;
  my $data = ref($id) ? $id : $self->LoadUser($id);
  return $self->classUser()->instance($self,$data);
}

sub ListMyJournals {
  my $self = shift;
  return undef unless getUser() ? getUser()->Get('id') : undef;
  return table('journal')->List({user_id=>getUser()->Get('id')});
}

sub ListOpenJournals {
  my ($self,$id) = @_;
  my $uid = getUser() ? getUser()->Get('id') : undef;
  my $query;
  if (getUser()) {
    if (getUser()->HasAccess('admin')) {
      $query = "select * from journal order by list_order";
    } elsif (getUser()->Get('level')) {
      $query = "select * from journal where access_journal>=2 or user_id=$uid order by list_order";
    } else {
      $query = "select * from journal where access_journal>=3 or user_id=$uid order by list_order";
    }
  } else {
    $query = "select * from journal where access_journal>=4 order by list_order";
  }
  return $self->{db}->SuperSelectAndFetchAll($query);
}

sub SendForgottenPassword {
  my ($self,$email) = @_;

  $email=lc($email);
  my $res = $self->{db}->
    SuperSelectAndFetchAll
      (qq(select id, password, name, login, email
        from fuser where lower(login)=? or email=?),$email,$email);
  return undef unless $res && @$res;
  foreach my $u (@$res) {
    my $auto_password;
    do {
      $auto_password = int(rand(9999999));
    } while ($auto_password<10000);
    table('fuser')->
      Modify({auto_password=>$auto_password},
             $u->{id});
    my $r = SendMail("$u->{email} ($u->{name})",'forgotten',
                     {login=>$u->{login},
                      auto_password=>$auto_password});
  }
  return $res;
}

sub online_seconds { '300 seconds'; }

sub WhoOnline {
  my $self = shift;
  my $online_seconds=online_seconds();
  my $list = $self->{db}->
    SuperSelectAndFetchAll(qq(select *
                              from fuser
                              where is_logged=?
                              and lasttime>=now()-interval '$online_seconds'
                              order by lasttime),
                           1);
  my %logins;
  my %ids;
  my $max;
  foreach (@$list) {
    $logins{$_->{login}}=$_;
    $ids{$_->{id}}=$_;
    $max=$_->{karma} if $_->{karma}>$max;
  }
  if ($max) {
    foreach (@$list) {
      if ($_->{karma}<=0) {
        $_->{fontsize}=0;
        next;
      }
      $_->{fontsize}=int(2+7*$_->{karma}/$max);
    }
  }

  return {list=>$list,
          ids=>\%ids,
          logins=>\%logins};
}


sub LoadJournalByLink {
  my ($self,$host,$path) = @_;
  #  die "'$host' '$path'";
  $path="" unless $path;
  my $res =
    $self->{db}->SuperSelectAndFetch(qq(select journal.*, fuser.name as author
                        from journal
                        left join fuser on fuser.id=journal.user_id
                        where journal.host=? and journal.path=?),
                                     $host,$path) || return undef;
  $res->{category_list}=table('topic_category')->List({journal_id=>$res->{id}});
  if ($res->{category_list} && @{$res->{category_list}}) {
    push @{$res->{category_list}},{id=>0,name=>'Все',topics=>$res->{topics}};
  }
  return $res;
}


#
# sub BanUser {
#   my ($self,$id,$days,$comment) = @_;
#   $self->{db}->Query(qq(update fuser set is_active='f',
#                         banned_from=now(),
#                         banned_to=now() + cast(? as interval),
#                         banned_comment = ?
#                         where id=?
#                        ),"$days days",$comment,$id);
#   $self->{db}->Commit();
# }
#
# sub UnbanUser {
#   my ($self,$id) = @_;
#   $self->{db}->Query(qq(update fuser set is_active='t'
#                         where id=?
#                        ),$id);
#   $self->{db}->Commit();
# }


sub LoadUser {
  my ($self,$id) = @_;
  return $id =~ /\D+/ ?
    $self->{db}->
      SuperSelectAndFetch
        (qq(select * from fuser where login=?), $id)
          : $self->{db}->
            SuperSelectAndFetch
              (qq(select * from fuser where id=?), $id);
}


sub ListUsers {
  my $self = shift;
  return $self->{db}->
    SuperSelectAndFetchAll
      (qq(select *
          from fuser
          order by timestamp));

}

sub ListJournals {
  my $self = shift;
  my $uid = getUser() ? getUser()->Get('id') : undef;
  return $self->{db}->SuperSelectAndFetchAll
    (qq(select journal.*, fuser.name as author
        from journal
        left join fuser on fuser.id=journal.user_id
        order by journal.list_order, journal.name)) unless $uid;

  my $list = $self->{db}->SuperSelectAndFetchAll
    (qq(select journal.*, fuser.name as author,
        EXTRACT(second from journal.last_topic_time - journal_views.last_topic_time) as seconds,
        journal_views.last_topic_time as view_last_topic_time,
        journal_views.new_topics
        from journal
        left join fuser on fuser.id=journal.user_id
        left join journal_views on journal_views.user_id=? and journal_views.journal_id=journal.id
        order by journal.list_order, journal.name),$uid);
  my $need_commit=0;
  foreach (@$list) {
    if ($_->{seconds}) {
      my $res = $self->{db}->SuperSelectAndFetch
        (qq(select count(*) as count from topic where journal_id=? and create_time>?),
         $_->{id},$_->{view_last_topic_time});
        $_->{new_topics}=$res->{count};
      $self->{db}->Query("update journal_views set new_topics=?, last_topic_time=? where journal_id=? and user_id=?",
            $res->{count} || 0,$_->{last_topic_time},$_->{id},$uid);
      $need_commit=1;
    }
  }
  $self->{db}->Commit()
    if $need_commit;
  return $list;
}

# sub SetNewTopicCounter {
#   my ($self,$uid) = @_;
#
# }


sub GenerateMobileCode {
  my $code;
  do {
    $code = int(rand(9999));
  } while (!$code);
  return $code;
}


sub SendSMS {
  my ($user,$message) = @_;
  my $converter = Text::Iconv->new("koi8-r", "cp1251");
  $message=uri_escape($converter->convert($message));
  my $url = "http://www.shgsm.ru/esme/transmitter.php?id=DC16-847R&daddr=$user->{mobile}&msg=$message";
  my $http = new HTTP::Lite;
  my $req = $http->request($url) or return undef;
  my $res = $http->body();
  print STDERR "send SMS $message to user $user->{id} - $user->{mobile}: $res\n";
  return $res =~ /OK/ ? $user->{mobile_code} : undef;
}


sub SendMobileCode {
  my ($user) = @_;
  return 1; # FAKE
  
  my $converter = Text::Iconv->new("koi8-r", "cp1251");
  my $message=uri_escape($converter->convert("$user->{login}, ваш код подтверждения на zhazhda.ru: $user->{mobile_code}"));
  my $url = "http://www.shgsm.ru/esme/transmitter.php?id=DC16-847R&daddr=$user->{mobile}&msg=$message";
  my $http = new HTTP::Lite;
  my $req = $http->request($url) or return undef;
  my $res = $http->body();
  print STDERR "send mobile code $user->{mobile_code} to user $user->{id} - $user->{mobile}: $res ($url)\n";
  return $res =~ /OK/ ? $user->{mobile_code} : undef;
}

sub SendEmailCode {
  my ($user,$generate_new) = @_;
  return 123;
}


sub ModifyUser {
  my ($self,$uid,$h) = @_;
  $uid+=0;
  my $user = table('fuser')->Load($uid) || fatal("No such user $uid");
#   $h->{login}=~s/^\s+//g;
#   $h->{login}=~s/\s+$//g;
  setContext('fields',$h);
  my (%e,%f);
  setContext('bad_fields',\%f);
  setContext('errors',\%e);
  $h->{mobile}=~s/\D+//g; $h->{mobile}=~s/^8/7/;
  $h->{email}=~s/^\s+//g;
  $h->{email}=~s/\s+$//g;
  $h->{email}=lc($h->{email});
  if (!Email::Valid->address($h->{email})) {
    $e{email}=1;
    $f{email}=1;
  }
#   if (!IsMobileValid($h->{mobile})) {
#     $e{mobile}=1;
#     $f{mobile}=1;
#   }
  if (!exists $e{mobile} && ($h->{mobile} ne $user->{mobile})) {
     if (table('fuser')->
         Load({mobile=>$h->{mobile},
               and=>["id <> ".$uid]})) {
       # TODO высылать на мобильный телефон логин и пароль старого пользователя.
       $e{mobile_exists}=1;
       $f{mobile}=1;
     } else {
      $h->{level}=0;
      $h->{mobile_checked}=undef;
      $h->{mobile_code}=GenerateMobileCode();
      $h->{mobile_tries}=0;
      $user->{mobile}=$h->{mobile};
      $user->{mobile_code}=$h->{mobile_code};
      if (SendMobileCode($user)) {
        setContext('mobile_changed',1);
      } else {
        $e{mobile2}=1;
        $f{mobile}=1;
      }
    }
  }
  if (!exists $e{email} && ($h->{email} ne $user->{email})) {
    $h->{email_changed}='now()';
    $h->{email_checked}=undef;
    $h->{email_tries}=0;
    $user->{email}=$h->{email};
    if ($h->{email_code}=SendEmailCode($user,1)) {
      setContext('email_changed',1);
    } else {
      $e{email2}=1;
      $f{email}=1;
    }
  }
  return undef if keys %e;
  $h->{change_time}='now()';
  $h->{sms_subscribe}+=0;
  print STDERR "modify user $uid".join(',',%$h)."\n";
  my $res = table('fuser')->Modify($h,$uid);
  db()->Commit();
  return 1;
}

sub SignUser {
  my ($self,$form,$session) = @_;
  my $h = $form->Fields();
  # empty - не все поля заполненны
  # password - не верный пароль
  # exists - такой логин уже существует
  $h->{password}=md5_hex($h->{password} || $h->{password1});
  delete $h->{password2};
  delete $h->{password1};
  # Сделать обязательные поя настраиваемыми, phone
  $h->{mobile}=~s/\D+//g; $h->{mobile}=~s/^8/7/;
  $h->{login}=~s/^\s+//g;
  $h->{login}=~s/\s+$//g;
  $h->{email}=~s/^\s+//g;
  $h->{email}=~s/\s+$//g;
  $h->{email}=lc($h->{email});
  
  $h->{city_id}=1;
  my $lc = lc($h->{login});
  if ($h->{mobile} && table('fuser')->
      Load({mobile=>$h->{mobile}})) {
    $form->AddError('mobile','registered');
  }
  if ($h->{login} && table('fuser')->Load(["lower(login)='$lc'",{is_removed=>'f'}])) {
    $form->AddError('login','registered');
  }
  return undef if $form->Errors();
  $h->{sign_ip}=setting('uri')->{remote_ip};
  $h->{last_ip}=setting('uri')->{remote_ip};

  $h->{mobile_checked}=undef;
  $h->{mobile_code}=GenerateMobileCode();
  $h->{mobile_tries}=0;

  #  $h->{is_logged} = 1;
  # Заглушка
  $h->{session} = dpl::Web::Session::generate();
  my $res = table('fuser')->Create($h);
  SendMobileCode($res);
  db()->Commit();
  fatal("Unknown error while sign user $res") unless $res;
  return $res;
}



# выс вызывают эту функцию со своими параметрами.


sub _listTopics {
  my ($h) = @_;
  # Параметры хеша:
  # fields, table_from, where{}, order, start, limit, bind[]

  startTimer('list_topics');

  my $t = $h->{topic_table} || 'topic';
  my $tl = $h->{topic_link_table};
  #my $db = $h->{db} || el::Db::db();
  my $db = $h->{db} || el::Db::db();
    # Собираем список запрашиваемых полей
  my $fields = " $t.*, $user_fields ";

  my @tlf=qw(is_on_top is_bold is_red is_sticky is_hot is_cold timestamp
             image_id image_time show_text short_text image_mode);
  $fields=" $fields ,".join(' , ',map {"$tl.$_"} @tlf) if $tl;

  my @bind;

  # Добавляем данные о просмотре страниц пользователем
  my $blacks={};
  my $user = $h->{user} || getUser();
  if ($user) {
    $fields.=qq(,topic_views.last_view_comment_id, topic_views.last_view_file_id
                ,topic_views.last_view_time
                ,topic_views.new_files
                ,topic_views.new_comments, topic_views.is_subscribed
                ,topic_views.new_answers, topic_views.answers
               );
    $h->{table_from}=" left join topic_views on (topic_views.user_id=? and topic_views.topic_id=$t.id) $h->{table_from}";
    push @bind, $user->Get('id');
    $blacks=$user->BlackList()->{hash}
      if $h->{use_blacks};
  }

  $fields.=", $h->{fields}" if $h->{fields};


  # добавляем file-image
  my $tw = $t;
  if ($tl) {
    my @f = qw(path file thumb_file thumb_width thumb_height gallery_file gallery_width gallery_height);
    $fields.=", ".join(', ',map {"filesholder_file.$_ as file_$_"} @f);
    $h->{table_from}=" left join filesholder_file on (filesholder_file.id=$tl.image_id) $h->{table_from}";
    $tw = "$tl left join $t on $tl.topic_id=$t.id";
  }

  my $query = qq(select distinct $fields from $tw
                 $h->{table_from}
                 left join fuser on fuser.id=$t.user_id
                 where );
  #                 where $tl.journal_id=?
  #and $t.is_moderated - уже стоит, иначе бы её не прилинковали.
#  push @bind, $self->{id}; # journal_id

  # без where вообще не может быть
#  if ($h->{where}) {
  my @w;
  if (ref($h->{where})=~/HASH/) {
    foreach (keys %{$h->{where}}) {
      push @w,$_=~/\./ ? "$_=?" : "$t.$_=?";
      push @bind,$h->{where}->{$_};
    }
    $query.=join(' and ',@w);
  } elsif (ref($h->{where})=~/ARRAY/) {
    foreach (@{$h->{where}}) {
      push @w,$_;
    }
    $query.=join(' and ',@w);
  } else {
    $query.=" $h->{where}";
  }
  # }
  push @bind,@{$h->{bind}} if $h->{bind};

  # Добавляем сортировку
  unless ($h->{order}) {
    $h->{order}=$tl ? "$tl.timestamp desc " : "$t.create_time desc ";
  }

  $query.= " order by $h->{order} ";
#  die join(',',%$h);
  # Собираем limit и start
  if ($h->{limit}) {
    $query.= " limit ? ";
    push @bind,$h->{limit}+0;
  }

  if ($h->{start}) {
    $query.=" offset ? ";
    push @bind,$h->{start}+0;
  }
  # Сбор тем
#  print STDERR "Query: $query:",join(',',@bind),"\n";
  my $sth = $db->
    sqlQuery($query,@bind);
  my $max_cols = exists $h->{cols} ? $h->{cols} : 2;
  my $max_top_cols = exists $h->{top_cols} ? $h->{top_cols} : 2;
  my $top_col=0;

  my $col=0;


  my $max_hot_cols = exists $h->{hot_cols} ? $h->{hot_cols} : 2;
  my $hot_col=0;

  my $max_cold_cols = exists $h->{cold_cols} ? $h->{cold_cols} : 2;
  my $cold_col=0;

  my $day_col=0;
  my $all_col=0;
  my %top = (cols=>[],all=>[],gallery=>[]);
  my %other = (cols=>[],all=>[],gallery=>[]);
  my @days;
  my @new;
  my %hot = (cols=>[],all=>[],gallery=>[]);
  my %cold = (cols=>[],all=>[]);
  my @all;
  my @cols=([],[]);
  my %res=(all=>\@all,
           cols=>\@cols);
  my %fotos;
  my %topics;
  if ($h->{sort_result}) {
    $res{top}=\%top;
    $top{cols}=[map {[]} (1..$h->{top_max_cols})];

    $res{other}=\%other;
    $other{cols}=[map {[]} (1..$h->{max_cols})];

    $res{days}=\@days;

    $res{hot}=\%hot;
    $res{new}=\@new;

    $res{cold}=\%cold;
  }
  $res{min_rating}='5.00';
  $res{max_rating}=0;
  my $old_day;
  my $cdh;
  my $f = context('filter');
  my $t;
  
  while ($t=$sth->fetchrow_hashref()) {
#     next if $h->{use_filter} && $f eq 'images_only' && !$t->{images};
#     next if $h->{use_filter} && $f eq 'media_only' && !($t->{music} || $t->{video});
#    next if $f eq 'hot_only' && !($t->{is_top} || $t->{is_hot});
    $t->{event_time}=~s/\:00$//;
    if ($user) {
      $t->{is_new}=!$t->{last_view_time};
      next if $h->{use_blacks} && $blacks->{$t->{user_id}};
    }
    next if exists $topics{$t->{id}};

    if ($h->{load_music} && $t->{music}) {
        my $m = db()->
            SuperSelectAndFetchAll("select * from filesholder_file where topic_id=$t->{id} and type='music' order by id");
        $t->{music_files}=$m;
    }

    if ($h->{load_video} && $t->{video}) {
        my $m = db()->
            SuperSelectAndFetchAll("select * from filesholder_file where topic_id=$t->{id} and (type='video' or type='youtube') order by id");
        $t->{video_files}=$m;
    }

    
    $topics{$t->{id}}=$t;
    #    next if $h->{use_filter} && $f eq 'new_only' && !$t->{is_new};

    $res{min_rating}=$t->{rating} if $t->{rating}<$res{min_rating};
    $res{max_rating}=$t->{rating} if $t->{rating}>$res{max_rating};
    $t->{image_mode}=1 if $t->{topic_type} eq 'gallery';
    $fotos{$t->{id}}=[]
      if $t->{image_mode};
    if ($h->{sort_result}) {
      push @new,$t if $t->{is_new};
      if ($t->{is_on_top}) {
        if ($t->{image_mode}) {
          push @{$hot{all}},$t;
          push @{$hot{gallery}},$t;
        } else {
          push @{$top{all}},$t;
          push @{$top{cols}->[$top_col]},$t;
          $top_col++; $top_col=0 if $top_col==$max_top_cols;
        }
      } elsif ($t->{is_hot}) {
#        print STDERR "variant3\n" if $t->{id}==61740;
        #      } elsif ($t->{is_hot} && (!$user || ($t->{is_fresh} || $t->{is_new} || $t->{new_comments}))) {
        push @{$hot{all}},$t;
        if ($t->{image_mode}) {
          push @{$hot{gallery}},$t;
        } else {
          push @{$hot{cols}->[$hot_col]},$t;
          $hot_col++; $hot_col=0 if $hot_col==$max_hot_cols;
        }
      } elsif ($t->{is_cold}) {
#        print STDERR "variant5\n" if $t->{id}==61740;
        push @{$cold{all}},$t;
        push @{$cold{cols}->[$cold_col]},$t;
        $cold_col++; $cold_col=0 if $cold_col==$max_cold_cols;
      } else {

        push @{$other{all}},$t;
        push @{$other{cols}->[$col]},$t;
        $col++; $col=0 if $col==$max_cols;

        my $day = substr($t->{timestamp},0,10);
        unless ($old_day eq $day) {
#          print STDERR "variant42 ($old_day, $cdh->{day}, @{$cdh->{all}})\n"
          $cdh={day=>$day,
                all=>[],
                cols=>[map {[]} (1..$h->{max_cols})]};
 #         print STDERR "variant41 ($old_day, $day)\n";

          $old_day=$day;
          push @days,$cdh;

        }
  #      print STDERR "variant4 ($day_col, $day, $cdh->{day})\n" if $t->{id}==61740;
        push @{$cdh->{all}},$t;
        push @{$cdh->{cols}->[$day_col]},$t;
        $day_col++; $day_col=0 if $day_col==$max_cols;
      }
    }
#    print STDERR "variant6\n" if $t->{id}==61740;
    push @all,$t;
    push @{$cols[$all_col]},$t;
    $all_col++; $all_col=0 if $all_col==$max_cols;
  }
  if ($h->{get_fotos}) {
    foreach my $tid (keys %fotos) {
      my $res = $db->
        sqlSelectAll("select * from filesholder_file where topic_id=? and type='image' and thumb_height<=60 and is_moderated order by is_in_gallery desc, thumb_width, rating desc limit 7",
                               $tid);
      $res=$db->
        sqlSelectAll("select * from filesholder_file where topic_id=? and type='image' and thumb_height<=100 and is_moderated order by is_in_gallery desc, thumb_width, rating desc limit 7",
                     $tid)
          unless @$res;
      my ($max,$w)=(580);
      my @l;
      foreach (@$res) {
        my $t = $_->{thumb_width}+5;
        last if $w+$t>$max;
        $w+=$t;
        push @l,$_;
      }
      $topics{$tid}->{fotos}=@l ? \@l : undef;
    }
  }
  stopTimer('list_topics');
  return \%res;
}




1;
