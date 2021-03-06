# -*- coding: koi8-r-unix -*-
package dpl::Web::Forum::User;
use strict;
use Exporter;
use dpl::Web::User;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Config;
use dpl::Db::Filter;
use dpl::Web::Utils;
use dpl::Error;
use dpl::Context;
use File::Path;
use LittleSMS;

use GD;
use Digest::MD5 qw(md5_hex);
use vars qw(@ISA);
@ISA = qw(dpl::Web::User);

#sub GetTableName { 'fuser'; }

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
  return undef                  # ������������ ��������
    unless $res && !$res->{is_removed};
  return $res;
}


sub IncrementBannersCount {
  my $self = shift;
  db()->Query("update fuser set banners=banners+1 where id=?",$self->Get('id'));
}

sub DecrementBannersCount {
  my $self = shift;
  db()->Query("update fuser set banners=banners-1 where id=?",$self->Get('id'));
}



sub Black {
  my ($self,$bid,$comment)=@_;
  return undef unless $bid && $self->IsLoaded();
  my $uid = $self->Get('id');
  fatal("������ ������ ���� �������� � ��")
    if $bid==$self->Get('id');
  my $db = db();
  $db->Begin();
  $db->Query('select * from fuser where id=? for update',$bid);
  unless (table('blacks')->
          Load({user_id=>$uid,
                black_id=>$bid})) {
    $db->Query('update fuser set blacked=blacked+1 where id=?',$bid);
    table('blacks')->
      Create({user_id=>$uid,
              black_id=>$bid,
              comment=>$comment});
  }
  $db->Commit();
  $self->BlackList(1);
}

sub post_load {
  my $self = shift;
  setContext('blacklist',$self->BlackList());
}

sub Unblack {
  my ($self,$bid)=@_;
  return undef unless $bid && $self->IsLoaded();
  my $uid = $self->Get('id');
  fatal("������ ������ ���� �������� � ��")
    if $bid==$self->Get('id');
  my $db = db();
  $db->Begin();
  $db->Query('select * from fuser where id=? for update',$bid);
  if (table('blacks')->
          Load({user_id=>$uid,
                black_id=>$bid})) {
    $db->Query('update fuser set blacked=blacked-1 where id=?',$bid);
    table('blacks')->
      Delete({user_id=>$uid,
              black_id=>$bid});
  }
  $db->Commit();
  $self->BlackList(1);
}

# �������� �� ������� ���� � �� � uid

sub IsBlacker {
  my ($self,$uid) = @_;
  return table('blacks')->
    Load({user_id=>$uid,
          black_id=>$self->Get('id')});
}

sub BlackList {
  my ($self,$force) = @_;
  my $db = db();
  if ($force || !$self->{blacks}) {
    my $uid = $self->Get('id');
    my $sth = $db->Query("select *, $dpl::Web::Forum::user_fields from blacks left join fuser on fuser.id=blacks.black_id  where user_id=?",
                         $uid);
    my @list;
    my %hash;
    while (my $a = $db->Fetch($sth)) {
      push @list,$a;
      $hash{$a->{id}}=$a;
    }
    if ($self->{blacks}) {
      $self->{blacks}->{list}=\@list;
      $self->{blacks}->{hash}=\%hash;
    } else {
      $self->{blacks}={list=>\@list,
                       hash=>\%hash};

    }
  }
  return $self->{blacks};
}

sub ChangePassword {
  my $self = shift;
  my $password = shift;
  $self->{table}->
    Modify({password=>$self->encrypt_password($password),
            auto_password=>undef},
           $self->Get('id'));
}


sub encrypt_password {
  my ($self,$password)=@_;
  return md5_hex($password);
}

sub getTempDir {
  my $self = shift;
  my $p = "/tmp/zhazhda/users/".$self->Get('id');
  unless (-d $p) {
    mkpath($p) || fatal("can't create temp dir $p");
  }
  return $p;
}

sub getAvatarDir {
  my $self = shift;
  return directory('user');
}

sub GetNextFreshTopic {
  my ($self,$topic_id)=@_;

  my $a = dpl::Web::Forum::_listTopics({where=>
                                        ['topic_views.user_id=?','(topic_views.new_answers>0 AND not is_subscribed) OR is_freshed'],
                                        bind=>
                                        [$self->Get('id')]});
  shift @{$a->{all}}
    if $a->{all} && $topic_id==$a->{all}->[0]->{id};
  return $a->{all}->[0]
    if @{$a->{all}};

  return undef;
#   my $a = dpl::Web::Forum::_listTopics({where=>
#                                         ['topic_views.user_id=?','(topic_views.new_answers>0 AND not is_subscribed) OR is_freshed'],
#                                         bind=>
#                                         [$self->Get('id')]});


}

sub LoadAvatar {
  my ($self,$file) = @_;
  my $dir = $self->getAvatarDir();
  my $src_file = dpl::Web::Utils::receiveFile($self->getTempDir(),$file) || return undef;
  my $f = new File::PathInfo;
  $f->set($src_file) or die("file does not exist $src_file");
  my $ext = $f->ext();
  my $filename=$f->filename_only();
  my %types=(gif=>1,jpg=>1,jpeg=>1,png=>1);
  fatal("Unknown file type '$ext'. Must be on of ".join(',',keys %types))
    unless exists $types{$ext};

  my $src = GD::Image->new($src_file) || fatal("Error open file: $src_file");

  my %h = (image_time=>'now',
           thumb_time=>'now',
           image_file=>$self->Get('id')."-orig.$ext",
           thumb_file=>$self->Get('id').".$ext",
          );
  my $size;
  ($size,$h{image_width},$h{image_height})=
    dpl::Web::Utils::resampleImage($src_file,$dir,$self->Get('id')."-orig",$ext,$src,600,450);

  ($size,$h{thumb_width},$h{thumb_height})=
    dpl::Web::Utils::resampleImage($src_file,$dir,$self->Get('id'),$ext,$src,80,200);

  $self->Modify(\%h);
}

sub GetPrivateMailsPages {
  my ($self,$talker_id) = @_;
  my $limit = 10;
  my $db = db();
  my $user_id = $self->Get('id');
  my $pages = $db->SuperSelectAndFetch('select count(*) as count from mail where user_id=? and talker_id=?',$user_id,$talker_id);
  $pages=$pages->{count}/$limit
    if $pages;
  $pages=1 if $pages<1;
  $pages++ if $pages=~s/[.,].+$//;
  return $pages;
}

sub GetNewMailIndex {
  my $self = shift;
  my $user_id = $self->Get('id');
  my $db = db();
  my $sth = $db->Query("select mail_box.*, fuser.id as talker_id, $dpl::Web::Forum::user_fields from mail_box left join fuser on fuser.id=mail_box.talker_id where user_id=? and mail_box.new_mail>0 order by timestamp desc",
                       $user_id);
  my @list;
  while (my $a = $db->Fetch($sth)) {
    $a->{talker} = {id=>$a->{talker_id},
                    level=>$a->{level},
                    icon=>$a->{icon},
                    lasttime=>$a->{lasttime},
                    login=>$a->{login}};
    push @list,$a;
  }
  return \@list;
}

sub HasNewMailsOfUser {
  my ($self,$talker_id) = @_;
  my $user_id = $self->Get('id');
  my $res = db()->SuperSelectAndFetch("select count(*) as count from mail_box where user_id=? and talker_id=? and mail_box.new_mail>0",
                                      $user_id,$talker_id);
  return $res ? $res->{count} : undef;
}

sub GetMailArchive {
  my $self = shift;
  my $user_id = $self->Get('id');
  my $db = db();
  my $sth = $db->Query("select mail_box.*, fuser.id as talker_id, $dpl::Web::Forum::user_fields from mail_box left join fuser on fuser.id=mail_box.talker_id where user_id=? and mail_box.new_mail=0 order by timestamp desc",
                       $user_id);
  my @list;
  while (my $a = $db->Fetch($sth)) {
    $a->{talker} = {id=>$a->{talker_id},
                    level=>$a->{level},
                    icon=>$a->{icon},
                    lasttime=>$a->{lasttime},
                    login=>$a->{login}};
    push @list,$a;
  }
  return \@list;
}


sub ClearPrivateMail {
  my ($self,$talker_id) = @_;
  my $user_id = $self->Get('id');
  my $db = db();
  $db->Begin();
  my $u = $db->Query('select * from fuser where id=? for update',$user_id);
  my $t = $db->Query('select * from fuser where id=? for update',$talker_id);

  my $user_inbox = $db->
    SuperSelectAndFetch('select * from mail_box where user_id=? and talker_id=?',
                        $user_id,$talker_id);
  my $talker_inbox = $db->
    SuperSelectAndFetch('select * from mail_box where user_id=? and talker_id=?',
                        $talker_id,$user_id);
#  die "$user_inbox->{new_mail} - $talker_inbox->{new_mail}";
  $db->Query('update fuser set new_mail=new_mail-? where id=?',$user_inbox->{new_mail},$user_id)
    if $user_inbox->{new_mail};
  $db->Query('update fuser set new_mail=new_mail-? where id=?',$talker_inbox->{new_mail},$talker_id)
    if $talker_inbox->{new_mail} && $talker_id!=$user_id;
  $db->Query('delete from mail_box where  (user_id=? and talker_id=?) or (talker_id=? and user_id=?)',
             $user_id,$talker_id,
             $user_id,$talker_id
            );
#   $db->Query('update mail_box set incomings=0, outcomings=0, last_incoming=NULL, new_mail=0 where (user_id=? and talker_id=?) or (talker_id=? and user_id=?)',
#              $user_id,$talker_id,
#              $user_id,$talker_id
#             );
  $db->Query('delete from mail where (user_id=? and talker_id=?) or (talker_id=? and user_id=?)',
             $user_id,$talker_id,
             $user_id,$talker_id
            );
  $db->Commit();
}

sub GetPrivateMails {
  my ($self,$talker_id,$page) = @_;
  my @list;
  my $user_id = $self->Get('id');
  $page=1 unless $page;

  my $limit = 10;
  my $start = ($page-1)*$limit;

  my $db = db();
  $db->Begin();
  my $ru = $db->Query('select * from fuser where id=? for update',$user_id);
  my $rinbox = $db->Query('select * from mail_box where user_id=? and talker_id=? for update',$user_id,$talker_id);
  my $sth = $db->
    Query(qq(select mail.*, $dpl::Web::Forum::user_fields from mail
             left join fuser on (fuser.id=mail.talker_id)
             where user_id=? and talker_id=?
             order by createtime desc
             offset $start limit $limit),
          $user_id,$talker_id);
  my @s;
  while (my $a = $db->Fetch($sth)) {
    #    $a->{createtime}=HumanTime(filter('datetime')->FromSQL($a->{createtime}));
    #    $a->{message}=FormatText($a->{message},0,1);
    $a->{talker} = {id=>$a->{talker_id},
                    mobile_checked=>$a->{mobile_checked},
                    level=>$a->{level},
                    icon=>$a->{icon},
                    login=>$a->{login}};
    push @s,$a if !$a->{is_shown} && $a->{is_inbox};
    push @list,$a;
  }
  if (scalar @s) {
    $db->Query('update mail_box set last_view=now(), new_mail=new_mail-? where user_id=? and talker_id=?',
               scalar @s, $user_id, $talker_id);
    $db->Query('update fuser set new_mail=new_mail-? where id=?',
               scalar @s, $user_id);
    $db->Query("update mail set is_shown='t', showtime=now() where ".join(' or ',map {"id=$_->{id}"} @s));
  }
  db()->Commit();
  return {mails=>\@list,
          page=>$page,
          limit=>$limit};
}


sub SendPrivateMail {
  my ($self,$to,$message) = @_;
  my $uid = $self->Get('id');
#   if ($to eq '@all' && $self->user()->Get('is_admin')) {
#     my $list = table('user')->List();
#     foreach (@$list) {
#       $self->user()->SendPersonalMail($_->{id},$message);
#     }
#     return $to;

  if ($to eq '\@sms' && $self->Get('is_admin')) {
    my $sth = db()->Query(qq(select * from fuser where sms_event_type>0));
    while (my $a = db()->Fetch($sth)) {
      $self->SendPrivateMail($a->{id},$message);
    }
    return $to;
  }
  
  db()->Begin();
  my $user = $to=~/^(\d+)$/ ?
    db()->SuperSelectAndFetch('select * from fuser where id=? for update',$to)
      : db()->SuperSelectAndFetch('select * from fuser where login=? for update',$to);
  
  if ($user && !$self->IsBlacker($user->{id})) {
    my $inbox =
      db()->SuperSelectAndFetch('select * from mail_box where user_id=? and talker_id=? for update',
                                $user->{id},$uid);
    my $outbox =
      db()->SuperSelectAndFetch('select * from mail_box where talker_id=? and user_id=? for update',
                                $user->{id},$uid);

    db()->Query('insert into mail (user_id, talker_id, message) values (?,?,?)',
                $uid,
                $user->{id},
                $message);

    db()->Query('insert into mail (user_id, talker_id, is_inbox, message) values (?,?,?,?)',
                $user->{id},
                $uid,
                't',
                $message);
    if ($inbox) {
      db()->Query('update mail_box set incomings = incomings + 1, new_mail = new_mail + 1, last_incoming=now(), timestamp=now() where user_id=? and talker_id=?',
                  $user->{id},
                  $uid);
    } else {
      db()->Query('insert into mail_box (user_id, talker_id, new_mail, incomings, last_incoming) values (?,?,?,?,?)',
                  $user->{id},
                  $uid,
                  1,1,
                  'now()');
    }
    if ($outbox) {
      db()->Query('update mail_box set outcomings = outcomings + 1, last_outcoming=now(), timestamp=now() where talker_id=? and user_id=?',
                  $user->{id},
                  $uid);
    } elsif ($user->{id}!=$uid) {
      db()->Query('insert into mail_box (talker_id, user_id, outcomings, last_outcoming) values (?,?,?,?)',
                  $user->{id},
                  $uid,
                  1,'now()');
    }
    db()->Query('update fuser set new_mail = new_mail + 1, new_mail_timestamp=now() where id=?',$user->{id});
  }
  db()->Commit();
  return $user;
}

# sub SendSMS {
#   my ($user,$message) = @_;
#   my $converter = Text::Iconv->new("koi8-r", "utf-8");
#   $message=uri_escape($converter->convert($message));
#   my $url = "http://www.shgsm.ru/esme/transmitter.php?id=DC16-847R&daddr=$user->{mobile}&msg=$message";
#   my $http = new HTTP::Lite;
#   my $req = $http->request($url) or return undef;
#   my $res = $http->body();
#   print STDERR "send SMS $message to user $user->{id} - $user->{mobile}: $res\n";
#   return $res =~ /OK/ ? $user->{mobile_code} : undef;
# }

sub GenerateMobileCode {
  my $code;
  do {
    $code = int(rand(9999));
  } while (!$code);
  return $code;
}


sub ModifyUser {
  my ($self,$h) = @_;
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
  my $send_sms=0;
  
  if (!exists $e{mobile} && ($h->{mobile} ne $self->Get('mobile'))) {
     if (table('fuser')->
         Load({mobile=>$h->{mobile},
               and=>["id <> ".$self->Get('id')]})) {
       # TODO �������� �� ��������� ������� ����� � ������ ������� ������������.
       $e{mobile_exists}=1;
       $f{mobile}=1;
     } else {
      $h->{level}=0;
      $h->{mobile_checked}=undef;
      $h->{mobile_code}=$self->GenerateMobileCode();
      $h->{mobile_tries}=0;
      # $user->{mobile}=$h->{mobile};
      # $user->{mobile_code}=$h->{mobile_code};

      $send_sms=1;
      
      # if ($self->SendMobileCode()) {
      #   setContext('mobile_changed',1);
      # } else {
      #   $e{mobile2}=1;
      #   $f{mobile}=1;
      # }
    }
  }
  if (!exists $e{email} && ($h->{email} ne $self->Get('email'))) {
    $h->{email_changed}='now()';
    $h->{email_checked}=undef;
    $h->{email_tries}=0;
    # $user->{email}=$h->{email};
    # if ($h->{email_code}=$self->SendEmailCode(1)) {
    #   setContext('email_changed',1);
    # } else {
    #   $e{email2}=1;
    #   $f{email}=1;
    # }
  }
  return undef if keys %e;
  $h->{change_time}='now()';
  $h->{sms_subscribe}+=0;
  #print STDERR "modify user $uid".join(',',%$h)."\n";
  $self->Modify($h);
  $self->SendMobileCode() if $send_sms;
  # my $res = table('fuser')->Modify($h,$self->Get);
  db()->Commit();
  return 1;
}

sub SendEmailCode {
  my ($self,$generate_new) = @_;
  return 123;
}



sub SendSMS {
  my ($self,$message) = @_;
  my $converter = Text::Iconv->new("koi8-r", "utf-8");
  sms()->sendSMS( $self->Get('mobile'), $converter->convert($message));
}


sub SendMobileCode {
  my ($self) = @_;
  # print STDERR "send mobile code $user->{mobile_code} to user
  #$user->{id} - $user->{mobile}: $res ($url)\n";
  #$self->SendSMS($self->Get('login').", ��� ��� ������������� ��
  #zhazhda.ru: ".$self->Get('mobile_code')); 
  $self->SendSMS($self->Get('login').", your code is: ".$self->Get('mobile_code'));
}


1;
