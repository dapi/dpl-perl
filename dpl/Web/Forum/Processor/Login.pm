# -*- coding: koi8-r-unix -*-
package dpl::Web::Forum::Processor::Login;
use strict;
use Exporter;

use dpl::Context;
use dpl::System;
use dpl::Db::Table;
use dpl::Db::Database;
#use MIME::Lite;
#use MIME::Words;
#use Email::Send qw[SMTP Qmail];
use el::Web::Form;
use dpl::Web::Forum::Processor::Base;
use dpl::Web::Forum;

use vars qw(@ISA);
@ISA = qw(dpl::Web::Forum::Processor::Base);


# Процессор работает с личной записью пользователя

sub ACTION_my_journals {
  my $self = shift;
  my $list = forum()->ListMyJournals();
  return {journals=>$list};
}

sub ACTION_forget {
  my $self = shift;
  if ($self->user()->IsLoaded()) {
    $self->template('redirect');
    return '/';
  }
  return forum()->SendForgottenPassword($self->param('email'));
}

sub ACTION_black {
  my $self = shift;
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете занести пользователя в черный список?');
  
  my $id = $self->param('id');
  $self->user()->Black($self->param('id'));

  my $r =  setting('uri')->{referer};
  return $r if $r;

  $self->template('redirect');
  return "/profile/";
}

sub ACTION_unblack {
  my $self = shift;
  my $id = $self->param('id');
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете вынести пользователя в черный список?');
  $self->user()->Unblack($self->param('id'));

  my $r =  setting('uri')->{referer};
  return $r if $r;

  $self->template('redirect');
  return "/profile/";
}



sub ACTION_sign {
  my $self = shift;
  $self->addNav('sign');
  setContext('signing',1);
  return undef
    unless $self->param('submit');

  my $form =
    NewForm('sign',
            $self->GetParams(qw(login
                                password1 password2
                                name email mobile show_private)));
  setContext('form',$form);
  $form->Validate('login',
                  qw(login));
  $form->Validate('notempty',
                  qw(login name));
  $form->Validate('password',
                  qw(password));
  $form->Validate('mobile',
                  qw(mobile));
  
  $form->Validate('email',
                  qw(email));

  
  return undef
    if $form->Errors();
  
#  my $h = $self->GetParams(qw(login password1 password2 name email mobile show_private));
#  $h->{mobile}=~s/\D+//g;
#    if $form->Errors();
  # TODO вынести в форму
  
  #  $h->{city_id}=1;
  delete $form->{password2};
  
  my $res =
    forum()->SignUser($form)
      || return undef;

  $self->user()->Load($res);
  $self->user()->SendMobileCode();
  $self->session()->GenerateNew();
  $self->session()->Login($self->user());
  setContext('user',$self->user()->Get());
  $self->template('signed');

  return $res;
}


# sub IsClientBanned {
#   my ($self)=@_;
#   my $client = soap('client','find',{ip=>setting('uri')->{remote_ip}});
#   return undef unless $client;
#   my $res = db()->
#     SuperSelectAndFetch("select * from fuser where is_active='f' and client_id=?",
#                         $client->{client_id});
#   return undef;
#   setContext('banned',$res);
#   setContext('no_login',1);
#   return 1;
# }


sub ACTION_logout {
  my $self = shift;
  setContext('user',undef);
  $self->user()->
    Modify({is_logged=>0,
            session=>$self->user()->Get('id')})
      if $self->user()->IsLoaded();
  $self->session()->GenerateNew();
  return $self->param('r') || setting('uri')->{referer} || setting('uri')->{home};
}

sub isg {
    my $self = shift;
    $self->template('global_redirect');
    return setting('uri')->{referer};
}

sub ACTION_login {
  my $self = shift;
  my ($login,$password)=($self->param('login'),
                         $self->param('password'));
 my $is_gallery=setting('uri')->{referer}=~/gallery-club/;
  if ($self->user()->IsLoaded() && !$login) {
	  	return $self->isg() if $is_gallery;
    $self->template('redirect');
    return  '/';
  }
  my $res = $self->user()->LoadByLogin($login,$password,1);

  if ($res) {
    if ($self->user()->Get('is_removed')) {
      $self->template('notlogged');
      setContext('desc',$self->user()->Get('remove_comment'));
      return 6;
    } else {
      setContext('user',$self->user()->Get());
      $self->session()->Login($self->user());
      my $r = $self->param('r') || setting('uri')->{referer};
      $r='' if $r=~/sign/;
      $self->template('global_redirect')
        unless $self->param('r');
      unless ($self->user()->Get('mobile_checked')) {
        $self->template('redirect');
        return $self->isg() if $is_gallery;
        return '/profile/';
      }
      $r=~s/\?ssid.*$//;
      return  $r;
    }
  }
  if ($self->user()->IsLoaded()) {
    $self->template('redirect');
    return '/';
  }
  setContext('login',$login);
  $self->template('no_login');
  setContext('signup',1);
  return 5;
}


sub ACTION_set_city {
  my $self = shift;
  my $city_id = $self->param('city_id') || 1;
  $self->user()->Modify({city_id=>$city_id});
  db()->Commit;
  return 'afisha/';
}

sub ACTION_answers {
  my $self = shift;
  $self->addNav('answers');
  return {
          answers=>dpl::Web::Forum::_listTopics({where=>
                                                 ['topic_views.user_id=?','topic_views.new_answers>0 AND not is_subscribed'],
                                                 bind=>
                                                 [$self->user()->Get('id')]}),
          subscribe=>dpl::Web::Forum::_listTopics({where=>
                                                   ['topic_views.user_id=?','is_freshed'],
                                                   bind=>
                                                   [$self->user()->Get('id')]}),
          topics=>dpl::Web::Forum::_listTopics({where=>
                                                ['topic_views.user_id=?','is_subscribed AND not is_freshed'],
                                                bind=>
                                                [$self->user()->Get('id')]}),
          journals=>table('journal')->HashList()};
}

sub ACTION_answers_archive {
  my $self = shift;
  return {topics=>dpl::Web::Forum::_listTopics({where=>
                                                ['topic_views.user_id=?','topic_views.answers>0 and topic_views.new_answers=0'],
                                                bind=>
                                                [$self->user()->Get('id')]}),
          journals=>table('journal')->HashList()};
}

sub ACTION_sms {
  my $self = shift;
  $self->addNav('sms');
  return setContext('fields',$self->user()->Get());
}

sub ACTION_sms_edit {
  my $self = shift;
#  setContext('profiling',1);
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете отредактировать профиль?');
  my $h = $self->GetParams(qw( sms_event_type));
  my %m = (0=>'zhazhda.ru: SMS оповещение отключено',
           1=>'zhazhda.ru: Включено SMS оповещение о всех событиях Чебоксар',
           2=>'zhazhda.ru: Включено SMS оповещение только о лучших событиях в Чебоксарах');

  # $self->user()->SendMobileCode()
  # dpl::Web::Forum::SendSMS($self->user()->Get(),$m{$h->{sms_event_type}})
  # 	unless $self->user()->Get('sms_event_type')==$h->{sms_event_type};
	
  table('fuser')->Modify($h,$self->user()->Get('id'));
  db()->Commit();
  return '/sms/';
#  return setContext('fields',$self->user()->Get());
}


sub ACTION_profile {
  my $self = shift;
  $self->addNav('profile');
  return {user=>$self->user()->Get()};
}

sub ACTION_load_avatar {
  my $self = shift;
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете сменить аватар');
  $self->user()->LoadAvatar($self->param('file'));
  setContext('user',$self->user()->Get());
  db()->Commit();
  return '/profile/';
}


sub ACTION_mobile_code {
  my $self = shift;
  my $code = $self->param('code');
  my $c = $self->user()->Get('mobile_code');
  my %h;
  if ($code==$c) {
    setContext('mobile_code','good');
    $h{level}=1;
    $h{mobile_checked}='now()';
  } else {
    setContext('mobile_code','bad');
    $h{mobile_tries}=$self->user()->Get('mobile_tries')+1;
  }
  $self->user()->Modify(\%h);
  setContext('user',$self->user()->Get());
  db()->Commit();
  return $self->ACTION_profile();
}

sub ACTION_send_mobile {
  my $self = shift;
  if ($self->user()->SendMobileCode()) {
    setContext('mobile_code','sended');
  } else {
    setContext('mobile_code','problem');
  }
  return $self->ACTION_profile;
}

sub ACTION_draft {
  my $self = shift;
  $self->addNav('draft');
  return {
          list=>dpl::Web::Forum::_listTopics({where=>
                                              ['topic.user_id=?','topic.journal_id is null',
                                              'not topic.is_removed'],
                                              bind=>
                                              [$self->user()->Get('id')]}),
          journals=>table('journal')->HashList()
         }
}

sub ACTION_edit_form {
  my $self = shift;
  $self->addNav('profile');
  setContext('profiling',1);
  $self->template('edit_profile');
  setContext('community_list',[
                               {id=>'zhazhda',
                                name=>'zhazhda.ru',
                                style=>"background: url('/pic/icon/u1.png') no-repeat 0px 3px;  padding-left: 11px; margin-left: 0px; margin-right: 4px; padding-right: 2px;"
                               },

                               {id=>'drugoisport',
                                name=>'drugoisport.ru',
                                style=>"background: url('/pic/icon/ud1.gif') no-repeat 0px 3px;  padding-left: 13px; margin-left: 0px; margin-right: 4px; padding-right: 2px;"
                               },
                              ]);
  return setContext('fields',$self->user()->Get());
}


sub ACTION_change_password {
  my $self = shift;
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете сменить пароль?');
  $self->addNav('profile');
  setContext('profiling',1);
  my ($p1,$p2)=($self->param('password1'),$self->param('password2'));
  if ($p1 || $p2) {
    if ($p1 ne $p2) {
      setContext('errors',{password=>1});
    } else {
      $self->user()->ChangePassword($p1);
      return 1;
    }
  }
  setContext('fields',$self->user()->Get());
  return 0;
}


sub ACTION_edit {
  my $self = shift;
  return undef
    unless
      $self->CheckReferer('Вы действительно желаете отредактировать профиль?');
  $self->addNav('profile');
  setContext('profiling',1);
  my $h = $self->GetParams(qw(podcast_type podcast_name podcast_comment name email mobile web_community address comment show_private use_smile autoplay sms_subscribe));
  $h->{show_private}=0 unless $h->{show_private};
  $h->{use_smile}=0 unless $h->{use_smile};
	$h->{autoplay}=0 unless $h->{autoplay};
  $h->{podcast_name}=$self->user()->Get('login')
    if $h->{podcast_type} && !$h->{podcast_name};
  $h->{icon}=$h->{web_community} eq 'drugoisport' ? 'd' : '';
  return $self->ACTION_edit_form()
    unless $self->user()->ModifyUser($h);
  return '/profile/';
}


1;
