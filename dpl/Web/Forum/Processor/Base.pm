package dpl::Web::Forum::Processor::Base;
use strict;
use dpl::Web::Processor::Access;
use dpl::Context;
use dpl::System;
use dpl::Error;
use dpl::DataType::DateTime;
use Date::Parse;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Db::Filter;
use dpl::Web::Banner;
use Exporter;
use dpl::Web::Forum;
use dpl::Web::Forum::Journal;
use dpl::Web::Forum::Topic;
use dpl::Web::Forum::Session;
use dpl::Web::Forum::Escape;
#use Templaate::Plugin;
use URI::Escape;
use URI::Split  qw(uri_split uri_join);
use Number::Format qw(:subs);
use XML::LibXML;
use HTTP::Date;
use el::Web::Rating;
use dpl::Web::Forum::User;

#use Class::Loader;
use Class::Rebless;
use vars qw(@ISA
            %leftmenu
            @EXPORT);


@ISA = qw(Exporter
          dpl::Web::Processor::Access
         );

@EXPORT = qw(web_error);

my %templ_styles=(default=>{bgcolor=>'#e0e0e0',
                            color=>'white',
                            top_bg=>'/pic/stakan/juice/top.jpg',
                            medium_bg=>'/pic/stakan/juice/medium.jpg',
                            bottom_bg=>'/pic/stakan/juice/bottom.jpg',
                            class=>'white_bg',
                            width=>250,
                           },
                  drugoi=>{bgcolor=>'#e0e0e0',
                           color=>'white',
                             top_bg=>'/pic/stakan/drugoi/top.jpg',
                           medium_bg=>'/pic/stakan/drugoi/medium.jpg',
                             fon_bg=>'/pic/stakan/drugoi/fon.jpg',
                           bottom_bg=>'/pic/stakan/drugoi/bottom.jpg',
                           class=>'white_bg',
                           width=>214,
                          },
                  
                  cola=>{bgcolor=>'black',
                         color=>'white',
                         top_bg=>'/pic/stakan/cola/top.jpg',
                         medium_bg=>'/pic/stakan/cola/medium.jpg',
                         #                           fon_bg=>'/pic/stakan/cola/fon.jpg',
                         bottom_bg=>'/pic/stakan/cola/bottom.jpg',
                         class=>'black_bg',
                         height=>124,
                         width=>224,
                        },

                  cola2=>{bgcolor=>'black',
                          color=>'white',
                          top_bg=>'/pic/stakan/cola2/top.jpg',
                          medium_bg=>'/pic/stakan/cola2/medium.jpg',
                          fon_bg=>'/pic/stakan/cola2/medium.jpg',
                          bottom_bg=>'/pic/stakan/cola2/bottom.jpg',
                          class=>'right',
                          height=>110,
                          width=>"100%",
                        },

                  
                    big_cola=>{bgcolor=>'black',
                               color=>'wfhite',
                               top_bg=>'/pic/stakan/big_cola/top.jpg',
                               medium_bg=>'/pic/stakan/big_cola/medium.jpg',
                               bottom_bg=>'/pic/stakan/big_cola/bottom.jpg',
                               class=>'black_bg',
                               height=>195,
                               width=>320,
                              },
                  
                  
                    komunalka=>{bgcolor=>'#96bc9b',
                                 color=>'white',
                                 top_bg=>'/pic/stakan/komunalka/top.jpg',
                                 medium_bg=>'/pic/stakan/komunalka/medium.jpg',
                                #                                 fon_bg=>'/pic/stakan/komunalka/medium.jpg',
                                 bottom_bg=>'/pic/stakan/komunalka/medium.jpg',
                                 class=>'white_bg',
                                 width=>214,
                            },


                    journal=>{bgcolor=>'#fdc000',
                             color=>'white',
                             top_bg=>'/pic/stakan/journal/top.jpg',
                             medium_bg=>'/pic/stakan/journal/medium.jpg',
                             bottom_bg=>'/pic/stakan/journal/medium.jpg',
                             class=>'white_bg',
                             width=>214,
                            });



 %leftmenu=(

              # Левое меню

              draft=>{menu=>'Черновик',path=>'/draft/',
                      title=>'Черновик не опубликованных тем'},

              draft_src=>{menu=>'Черновик',path=>'/draft/',
                          title=>'Черновик не опубликованных тем'},

              edit_journal=>{menu=>'Профиль..',path=>'/edit_journal_form',
                             title=>'Изменить настройки журнала'},
              journal=>{menu=>'Журнал'},

              talker=>{type=>'talker'},

              places=>{menu=>'Места..',
                       path=>'/places/',
                       title=>'Места развлечения и отдыха'},

#               new_topic=>{menu=>'Создать тему..', path=>'/new_topic',
#                           title=>'Создать свою тему, анонс, фотоотчёт или голосование'},

            new_event=>{menu=>'Создать анонс..', path=>'/new_topic?topic_type=event',
                        title=>'Анонсировать мероприятие'},
            
            user=>{menu=>'Пользовательские дневники', path=>'/users/'},
            
            new_topic_src=>{menu=>'Создать тему..', path=>'/new_topic',
                            title=>'Создать свою тему для обсуждения'},
            
              new_journal=>{menu=>'Свой журнал', path=>'/sys/new_journal'},
              profile=>{menu=>'Профайл', path=>'/profile/',
                        title=>'Личный профиль и настройки'},
			
	     sms=>{menu=>'Анонсы на SMS', path=>'/sms/',
                        title=>'Управление рассылкой анонсов по SMS',
	     	class=>"menu bold"},


            src_mail=>{menu=>'Личная переписка',path=>'/mail/',
                       title=>'Личная переписка с другими пользователями'},
            new_mail=>{menu=>'Личная переписка',path=>'/mail/?new=1',
                       class=>'nm_menu'},

              src_answers=>{menu=>'Подписка',path=>'/answers/',title=>'Управление подпиской на темы и персоны'},
            new_answers=>{menu=>'Подписка',path=>'/answers/',
                          class=>'nm_menu'},

            archive=>{menu=>'Архив',path=>'/archive/'},


#             archive=>{menu=>'Архив сайта',path=>'http://archive.zhazhda.ru/',
#                        title=>'Архив сайта, 2005-2006 года.'},

              reklama=>{menu=>'Реклама на сайте',path=>'/reklama/',
                        title=>'Стоимость рекламы на сайте и прочая коммерческая информация',
                    class=>'menu bold'},
              users=>{menu=>'Авторы',path=>'/users/'},
            gallery=>{menu=>'Галерея',path=>'/gallery/'},
            moderate=>{menu=>'Фото-модератор',path=>'/moderate/'},
              banners=>{menu=>'Баннера',path=>'/banners/'},
              zhazhda=>{menu=>"Что есть Жажда?",path=>'/zhazhda/'},
            todo=>{menu=>"Todo list",path=>'/topics/56675.html'},

              
              stats=>{menu=>'Статистика',path=>'/stats/'},
              search=>{menu=>'Поиск..',path=>'http://www.yandex.ru/advanced.html?site=zhazhda.ru'},

            exit=>{menu=>"Выдох",path=>'/logout'},

            my_journals=>{menu=>'Мои журналы',path=>'/my_journals/'},

              # Главное меню

              journals=>{menu=>"Другие журналы..",nav=>"Журналы",path=>'/journals/'},

              home=>{menu=>"Жажда Жизни",journal_id=>1,path=>'http://zhazhda.ru/'},
              komunalka=>{menu=>'Коммуналка',path=>'/komunalka/', journal_id=>4},
              awards=>{menu=>'ZHAZHDA AWARDS',path=>'http://zhazhda.ru/awards/', journal_id=>8},
              drugoi=>{menu=>'Другой Спорт',path=>'http://drugoisport.ru/', journal_id=>7},
              afisha=>{menu=>'Афиша', path=>'/afisha/', journal_id=>2},
              music=>{menu=>'Музыка', path=>'/music/', journal_id=>3},
              design=>{menu=>'Дизайн', path=>'/design/', journal_id=>5},

              #

              sign=>{menu=>'Регистрация',path=>'/sign/'},

             );


sub cookieName { 'nz'; }
#sub userModule { 'on::Forum::User'; }

sub LoadFile {
  my ($self,$param_name,$dir,$newfile)=@_;
  my $file = $self->param($param_name);
  return undef unless $file;
  unless ($newfile) {
    $newfile=$file;
    $newfile=~s/^.*[\/\\]//g;
    $newfile=~s/\.\.//;
    $newfile=~s/[^a-z_0-9\-.]/_/ig;
  }
  open(W, "> $dir$newfile") || fatal("Can't open file $dir$newfile to write");
  while (<$file>) {
    print W $_;
  }
  close(W) || fatal("Can't close file $dir$newfile");
  return $dir.$newfile;
}


sub get_music {
  my $self = shift;
  my $l = shift;
  my $limit = $l ? "limit $l" : '';
  my $where = $self->{talker} ?
    "and filesholder_file.user_id=$self->{talker}->{id}" : '';
  db()->
    SelectAndFetchAll(qq(
select *, topic.subject, topic.text,
$dpl::Web::Forum::user_fields,
filesholder_file.timestamp as ts,
filesholder_file.id as file_id from filesholder_file
left join topic on topic.id=filesholder_file.topic_id
left join fuser on fuser.id=filesholder_file.user_id
where type='music' $where and filesholder_file.timestamp>='2008-07-01 00:00:00' order by ts desc
$limit
                     ));
}


sub ACTION_notfound {
  my $self = shift;
  $self->template('NOT_FOUND');
  setContext('notfound',$self->{page}->{tail});
  return 1;
}

sub SetBackurl {
  my ($self,$link) = @_;
  my $s = setting('uri')->{referer};
  return unless $s;

  $s=~s/.*\.zhazhda\.ru\///;

  return setContext('backurl','/') if $s eq $link && !$s;
  # добавил / так -как иначе наслаивались ссылки
  setContext('backurl',"/$link")
    if $s eq $link || (($link && $s=~/^$link[\?\#]?/x) ||
                            $s=~/^[\?\#]/x);
  return undef;
}

sub LoadAndInitJournal {
  my ($self,$jid) = @_;
  fatal("No journal to init") unless $jid;
  return $self->initJournal(LoadJournal($jid));
}


sub FileRatingClass {
  $el::Db::DB->{dbh}=db()->{dbh};
  return NewRating({item_table=>'filesholder_file',
                    rate_table=>'file_rating',
                    rate_table_item_id=>'file_id',
                   });

}

sub LoadTopicAndInitJournal {
  my ($self,$topic_id) = @_;
  my $t = table('topic')->Load($topic_id) || return undef;
  my $j = LoadJournal($t->{journal_id} || 1);
  $self->initJournal($j,JournalInstance($j));
  $self->LoadAndInitTopic($topic_id);
}

sub LoadAndInitTopic {
  my ($self,$topic_id,$jid) = @_;
  $self->LoadAndInitJournal($jid) if $jid;
  $self->{topic_instance} = TopicInstance($topic_id) || return undef;
  $self->{topic_id}=$topic_id;
  return $self->{topic} = $self->{topic_instance}->Get();
}

sub initJournal {
  my ($self,$journal,$journal_instance) = @_;

  
  $journal_instance = JournalInstance($journal) unless $journal_instance;
  $self->{journal}=$journal;
  $self->{journal_instance} = $journal_instance || fatal("Can't init journal '$journal->{id}'");#forum()->JournalInstance($journal);
  #  $journal->{home_link}=$journal->{link} eq 'zhazhda/' ? '' : $journal->{link};
  setContext('journal',$journal);
  my $s = 'cola2' || $journal->{templ_style} || 'default';
  setContext('style',$templ_styles{$s});
  $journal->{access}=$journal_instance->GetJournalAccess();
  setContext('title',$journal->{name}) unless $journal->{id}==1;

#  my %right;
 # map {$right{$_} = $journal->{"right_$_"}} qw(header medium footer bg_color text_color);

#  setContext('right',\%right);
  #  setContext('right_templ',"$journal->{templ_path}/right");
  return $journal;
}



sub LoadGallery {
  my ($self,$max) = @_;
  $max=25 unless $max;
  startTimer('gallery');
  my $g = db()->
    SelectAndFetchAll(qq(select * from filesholder_file where is_on_main and is_moderated order by rating desc, id desc));

  setContext('gallery',$g);
  my $raters=2;
  my $res;
  my $days=3;
  do {
    $res = db()->
      SelectAndFetchAll(qq(select * from filesholder_file
where is_moderated and rating>=4 and raters>=$raters
and timestamp>=now() - interval '$days days'
order by rating desc, raters desc limit 5));
    $days++;
  } while ($days<7 && @$res<3);
  #print STDERR "top ",scalar @$res,"\n";
  setContext('top_gallery',$res);
  stopTimer('gallery');
}

sub web_error {
  my ($num,$h) = @_;
  fatal($num);
}

sub sessionModule { 'dpl::Web::Forum::Session'; }
sub sessionTableName { 'fuser'; }

sub userTableName { 'fuser'; }

sub cookieName { 'ssid'; }
sub userModule { 'dpl::Web::Forum::User'; }

sub addNav {
  my $self = shift;
  my $nav = context('nav') || [{path=>'/',menu=>'Главная'}];
  my $menu = context('menu');
  my $last;
  foreach (@_) {
    my %a = %{$menu->{$_} || {name=>$_}};#fatal("Не найдено меню: $_")};
    $a{name}=$_;
    push @$nav, \%a;
    $last = $_;
  }
  $self->activeItem($last);
  setContext('nav',$nav);
}


sub activeItem {
  my ($self,$item) = @_;
  setContext('active',$item);
}

sub Banners {
  my ($self,$mirror) = @_;
  my %banners;
  #  my $path="$mirror/zhazhda/pic/banners/";
  my $path="/pic/banners/";
  my $b = dpl::Web::Banner->new('bnz');
  $b->init($self,db());
  foreach ($b->ListPositions()) {
    #    next if $_->{name} eq 'middle' && $self->user()->IsLoaded() && $self->user()->Get('level');
    my $b = $b->GetBannerToDisplay($_->{name});
    next unless $b;
    $b->{uri}=$path.$b->{file};
    $banners{$_->{name}}=$b;
  }
  $b->SetCookieToProcessor();
  $self->{banners}=$b;
  setContext('banners',\%banners);

}

sub CheckReferer {
  my ($self,$text) = @_;
  my $referer = setting('uri')->{referer};
  return 1 if !$referer || $referer=~/http:\/\/(www.)?zhazhda.ru/ || $referer=~/gallery-club.ru/;
  $self->template('check_referer');
  setContext('referer_uri',$referer);
  setContext('check_referer',$text);
  return undef;
}

sub init {
  my $self = shift;
  $self=$self->SUPER::init(@_);
  $el::Db::DB = el::Db->new();
  $el::Db::DB->{dbh}=db()->{dbh};
  
  my $filters = Template::Filters->new({
                                        FILTERS => {
                                                    mobile=> \&filter_mobile,
                                                    uri => \&uri_filter,
                                                    uri_escape => \&uri_filter,
                                                    unicode_escape => \&unicode_filter,
                                                    unicode_escape2 => \&unicode_filter2,
                                                    atom_date => \&atom_date,
                                                    atom_datetime => \&atom_datetime,
                                                    atom_today => \&atom_today, 
                                                    http_date =>  \&http_date,
                                                    mobile => \&filter_mobile,
                                                    seconds => \&filter_seconds,
                                                    #                                                    user => \&user_filter,
                                                    percent => \&percent_filter,
                                                    right_cut =>\&right_cut_filter,

                                                    filesize => \&filesize_filter,

                                                    comments => \&filter_comments,

                                                    is_weekend =>  \&filter_is_weekend,
                                                    is_today =>  \&filter_is_today,
                                                    date_afisha =>  \&filter_date_afisha,
                                                    date_afisha2 =>  \&filter_date_afisha2,
                                                    date_short =>  \&filter_date_short,
                                                    date =>  \&filter_date,
                                                    date_time =>  \&filter_date_time,
                                                    human => \&filter_human,
                                                    date_human => \&filter_date_human,
                                                    time =>  \&filter_time,
                                                    timestamp => \&filter_timestamp,
                                                    bbcode => \&filter_bbcode,
                                                    escape_text => \&filter_escape_text,
                                                    escape_subject => \&filter_escape_subject,
                                                    escape_subject_short => \&filter_escape_subject_short,
                                                    escape_short_text => \&filter_escape_short_text,
                                                    escape => \&filter_escape,
                                                    #  gravatar => \&show_gravatar,

                                                   },
                                       });
  $self->setViewOptions(LOAD_FILTERS=>$filters,
#                        LOAD_PLUGINS=>[$plugins]
                       );
  if ($self->user()->IsLoaded()) {
    my $nm = $self->user()->Get('new_mail');
    if ($nm) {
      $leftmenu{mail}=$leftmenu{new_mail};
      $leftmenu{new_mail}->{title}="Новые письма ($nm шт.)";
      setContext('new_mail',$nm);
    } else {
      $leftmenu{mail}=$leftmenu{src_mail};
    }


    my $na = $self->user()->Get('new_answers');

    setContext('next_topic',$self->user()->GetNextFreshTopic());
    my $t = today() + 60*60*24;
    setContext('tomorrow',$t);
    my $ft = $self->user()->Get('fresh_topics');
    if ($na && $ft) {
      $leftmenu{new_answers}->{title}="Новые ответы ($na) и темы ($ft)";
      $leftmenu{answers}=$leftmenu{new_answers};
    } elsif ($na) {
      $leftmenu{new_answers}->{title}="Новые ответы ($na)";
      $leftmenu{answers}=$leftmenu{new_answers};
    } elsif ($ft) {
      $leftmenu{new_answers}->{title}="Новые темы ($ft)";
      $leftmenu{answers}=$leftmenu{new_answers};
    } else {
      $leftmenu{answers}=$leftmenu{src_answers};
    }

    my $d = $self->user()->Get('draft_topics');
    $leftmenu{draft}->{menu}=$d ? "$leftmenu{draft_src}->{menu} ($d)"
      : $leftmenu{draft_src}->{menu};

  }
  $leftmenu{new_topic}=$leftmenu{new_topic_src};
  my $mirror='http://me.orionet.ru';
  my $ip = setting('uri')->{remote_ip};
  if ($ip=~/^10\.100\./ || $ip=~/^217\.107\.177/ || $ip=~/^213\.59\.74/ || $ip=~/^192\.168\./ || $ip=~/^81\.4\.242/  || $ip=~/^81\.4\.240/) {
    $mirror='http://ml.orionet.ru';
  }

  $self->Banners($mirror);
  setting('uri')->{mirror}="$mirror/zhazhda/";
  setting('uri')->{backpath}=setting('uri')->{path};
  setting('uri')->{pic}="/files";
#  setting('uri')->{pic}="$mirror/zhazhda/pic/";


  setContext('menu',\%leftmenu);

  setContext('online',forum()->WhoOnline());


  setContext('open_journals',forum()->ListOpenJournals());
#   setContext('open_journals',[{id=>1,name=>'Жажда Жизни',host=>'zhazhda.ru'},
#                               {id=>7,name=>'Другой спорт',host=>'drugoisport.ru'}]);

  setContext('city',{id=>1,name=>'Чебоксары'});

  # Установить ссылку назад

  my $referer = setting('uri')->{referer};
  if ($referer=~s/^.+zhazhda.ru\//\//) {
    setting('uri')->{back}=$referer;
  }

  setContext('style',$templ_styles{cola2});
  #   setContext('right',{header=>'cola/top.jpg',
  #                       medium=>'cola/medium.jpg',
  #                       footer=>'cola/bottom.jpg',
  #                       bg_color=>'black',
  #                       text_color=>'white'});

#  setAfisha();
  setContext('podcast_news',$self->get_music(3));

  dpl::Context::st('forum_init');
  return $self;
}

# 
# sub setAfisha {
#   my %afisha;
#   my $categories = join(' or ',map {"place_category_id=$_"} qw(2 3 4 1 7));
#   
#   $afisha{today}=db()->
#     SelectAndFetchAll(qq(select topic.*, substr(topic.event_time,1,5) as event_time from topic
# where journal_id=2 and topic_type='event' and event_date=date(now()) and not is_removed and ($categories) order by topic.event_time
# ));
#   
#   $afisha{tomorrow}=db()->
#     SelectAndFetchAll(qq(select topic.*, substr(topic.event_time,1,5) as event_time from topic
# where journal_id=2 and topic_type='event'  and event_date=date(now() + '1 day') and not is_removed and ($categories)  order by topic.event_time
# ));
#   
#   $afisha{soon}=db()->
#     SelectAndFetchAll(qq(select topic.*, substr(topic.event_time,1,5) as event_time from topic
# where journal_id=2 and topic_type='event'  and event_date>date(now() + '1 day') and not is_removed and ($categories)  order by topic.event_date, topic.event_time limit 7
# ));
# 
#   setContext('afisha',\%afisha);
# }



sub SUBACTION_no_login {
  my $self = shift;
  setContext('no_login',1);
  $self->template('no_login');
  return 1;
}

sub SUBACTION_no_access {
  my ($self,$no_user) = @_;
  #  print STDERR "NO ACCESS\n";
  setContext('no_access',1);
  setContext('back',$self->{page}->{path});
  $self->template('no_access');
  return 0;
}


1;
