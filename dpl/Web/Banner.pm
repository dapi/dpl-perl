package dpl::Web::Banner;
use dpl::Context;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Filter;
use CGI::Cookie;
use dpl::DataType::Date;
use dpl::System;
use strict;

#use base qw(Exporter);
use vars qw(@ISA
            @EXPORT);

@ISA = qw(dpl::Base
          Exporter);
@EXPORT = qw(ListBanners
             ListActivePositions
             ListVarieties
             CreateBanner
             GetBanner
             GetBannerToDisplay
             DeleteBanner
             GetDisplayLog
             ActivateDisplay
             DeactivateBanner
             DeactivateDisplay);


sub getTime {
  my $self = shift;
  $self->{timer}++;
  my $t = time() - 1151833469;
  return "$t$self->{timer}";
}

sub GetPositionsToDisplay {
  my $self = shift;
  my $sth = $self->{db}->Select("select * from banners_display order by id");
  my %pos;
  my @to_close;
  my $today = today();#dpl::DataType::Date->new();
  while ($_=$sth->fetchrow_hashref()) {
    my $date_to = filter('date')->FromSQL($_->{date_to});
    if ($date_to && $date_to<$today) {
      push @to_close,$_->{id};
    } else {
      $pos{$_->{position}}=[] unless $pos{$_->{position}};
      push @{$pos{$_->{position}}},$_;
    }
  }
  $sth->finish();
  foreach (@to_close) {
    $self->DeactivateDisplay($_,1);
  }
  return \%pos;
}

sub init {
  my ($self,$processor,$db) = @_;
  $self->{processor} = $processor;
  $self->{db}=$db;
  $self->{positions} = $self->GetPositionsToDisplay();
  my $c = $processor->cookies();

  $self->{last_showed} = $self->ParseCookie($processor->cookies()->{$self->{name}});
#  print STDERR 'cookies ',join(',', keys %$c),"\n";
#  print STDERR "bnz= $self->{last_showed}:",join(',',keys %{$self->{last_showed}}),"\n";
  #   foreach (keys %{$self->{banners}}) {
  #     $self->{bc}->{$_} = exists $bc->{$_} ? $bc->{$_} : {count=>0,time=>$self->getTime()};
  #   }

#  print STDERR $self->printBC('BC 1: ');
  return $self;
}

sub GetBannerToDisplay {
  my ($self,$position) = @_;
  #fatal("Not found position to display '$position'")
  return undef
    unless $self->{positions}->{$position};
  fatal("Can't show banner, last_showed is not defined")
    unless $self->{last_showed};

  # Выбрать следующий по счёту

  my $p;
  if ($self->{last_showed}->{$position}) {
    $p = $self->{last_showed}->{$position}+1;
#    print STDERR "Last showed: $self->{last_showed}->{$position}\n";
  } else {
    $p=int(rand(@{$self->{positions}->{$position}}));
#    print STDERR "!No last showed\n";
  }

  # Вернуться на первые если номер переполнен
  $p=0
    if $p>=@{$self->{positions}->{$position}};

  my $b = $self->{positions}->{$position}->[$p];
  $self->{last_showed}->{$position}=$p;
#  print STDERR "Banner selected is $position:$p $b->{file}\n";
  $self->UpdateBannerCounter($b->{id});
  return $b;
}



sub deinit {
  my $self  = shift;
  $self->SetCookieToProcessor();
}

# sub GetBannerToDisplay {
#   my ($self,$position) = @_;
#   my $last_time; # Время самого давно показываемого баннера
#   my $banner_id; # Самый давно показывамый баннер
#  # print STDERR $self->printBC('BC before: ');
#   foreach (keys %{$self->{bc}}) {
# #    print STDERR "Check ($_) !$last_time || $self->{bc}->{$_}->{time}<$last_time\n";
#     if (!$last_time || $self->{bc}->{$_}->{time}<$last_time) {
#       $last_time=$self->{bc}->{$_}->{time};
#       $banner_id=$_;
#     }
#   }
#   if ($banner_id) {
#     $self->{bc}->{$banner_id}->{count}++;
#     $self->{bc}->{$banner_id}->{time}=$self->getTime();
#   } else {
# #    print STDERR "ERROR! No banner to show selected! Get first..\n";
#     $banner_id = (keys %{$self->{banners}})[0];
#     $self->{bc}->{$banner_id}={count=>1,time=>$self->getTime()};
#   }
# #  print STDERR $self->printBC('BC: ');
#
#   $self->UpdateBannerCounter($banner_id);
#   return $self->{banners}->{$banner_id};
# }

sub CheckAccess {
  my ($self,$banner)=@_;
  $banner = $self->{db}->SuperSelectAndFetch('select * from banner where id=?',$banner)
    unless ref($banner);
  return 1 if getUser()->HasAccess('banner_admin');
  fatal("No access for the banner")
    unless getUser()->Get('id')==$banner->{user_id};
  return 1;
}


# Проверяем пользовательский лимит на баннеры
sub CheckUserLimit {
  my $self = shift;
  return 1 if getUser()->HasAccess('banner_admin');
  my $l = getUser()->Get('banners_limit');
  return 1 if getUser()->Get('banners')<$l;
  fatal("Не могу поставить баннер. Достигнут лимит ($l), уже установлено баннеров:",getUser()->Get('banners'));
}

sub ActivateDisplay {
  my ($self,$banner_id,$position,$date_to) = @_;
  fatal('No banner id') unless $banner_id;
  my $banner = $self->{db}->SuperSelectAndFetch('select * from banner where id=? for update',$banner_id);
  $self->CheckAccess($banner);
  $self->CheckUserLimit($banner,$position);
  $self->CheckPositionLimits($banner,$position);
#  die 'not available';
  $self->{db}->Query('insert into banners_display (file,link,type,width,height,banner_id,position,date_to,user_id) values (?,?,?,?,?,?,?,?,?)',
              (map {$banner->{$_}} qw(file link type width height)),
                     $banner_id,$position,$date_to,
                     getUser()->Get('id'));
  getUser()->IncrementBannersCount();
  $self->{db}->Query("update banner set is_active='t', date_from=case when date_from is null then now() else date_from end where id=?",$banner_id);
  $self->{db}->Commit();
}

sub SaveToDisplayLog {
  my ($self,$d,$user_id) = @_;
  $self->{db}->Query('insert into banners_log (banner_id,position,counter,date_from,active_user_id,deactive_user_id) values (?,?,?,?,?,?)',
                     $d->{banner_id},$d->{position},$d->{counter},
                     $d->{create_time},
                     $d->{user_id},
                     $user_id);
}

sub GetDisplayLog {
  my ($self,$id) = @_;
  return $self->{db}->SuperSelectAndFetchAll('select * from banners_log where banner_id=?',$id);
}

sub DeactivateDisplay {
  my ($self,$id,$auto) = @_;
  $self->CheckAccess($id)
    unless $auto;
  my $res = $self->{db}->SuperSelectAndFetch("select * from banners_display where id=? for update ",$id);
  my $c = $self->{db}->SuperSelectAndFetch("select count(*) as count from banners_display where banner_id=?",$res->{banner_id});
  if ($c->{count}>1) {
    $self->{db}->SuperSelect("update banner set counter = counter + ?, last_time=? where id=?",
                $res->{counter},$res->{last_time},$res->{banner_id});
  } else {
    $self->{db}->SuperSelect("update banner set is_active='f', counter = counter + ?, last_time=? where id=?",
                $res->{counter},$res->{last_time},$res->{banner_id});
  }

  if ($res->{user_id}) {
    $self->{db}->SuperSelect("update fuser set banners=banners-1 where id=? and banners>0",
                             $res->{user_id});
  }
  $self->{db}->SuperSelect("delete from banners_display where id=?",$id);
  $self->SaveToDisplayLog($res,$auto ? undef : getUser()->Get('id'));
  $self->{db}->Commit();
  return $res->{banner_id};
}

sub DeactivateBanner {
  my ($self,$id) = @_;

  $self->CheckAccess($id);
  my $res = $self->{db}->SuperSelectAndFetchAll("select * from banners_display where banner_id=? for update",$id);
  my $counter = 0;
  foreach (@$res) {
    $counter+=$_->{counter};
    $self->{db}->SuperSelect("delete from banners_display where id=?",$_->{id});
    $self->SaveToDisplayLog($_,getUser()->Get('id'));
    $self->{db}->SuperSelect("update fuser set banners=banners-1 where id=? and banners>0",
                             $_->{user_id})
      if $_->{user_id};
    
  }
  $self->{db}->SuperSelect("update banner set is_active='f', counter = counter + ?, last_time=now() where id=?",
              $counter,$id);
  $self->{db}->Commit();
}


sub DeleteBanner {
  my ($self,$id) = @_;
#   my $res  = $self->{db}->
#     SelectAndFetchOne('select * from banner where id=?',$id);
#   fatal("Can't delete used banner (id:$id)") if $res->{is_active};
  $self->{db}->Query("update banner set is_removed='t' where id=? and is_active='f'",$id);
  $self->{db}->Commit();
}

# Список разновидностей существующих баннеров

sub ListVarieties {
  my $self = shift;
  return $self->{db}->
    SuperSelectAndFetchAll(qq(select width, height
                              from banner where is_removed='f' group by width, height));
}

sub CheckPositionLimits {
  my ($self,$banner,$position) = @_;
  my @pos = $self->ListPositions();
  my $p;
  foreach (@pos) {
    if ($_->{name} eq $position) {
      $p=$_;
      last;
    }
  }
  fatal("No such position defined ($position)") unless $p;
  foreach (qw(size width height)) {
    fatal("Banner's $_ is bigger then permitted ($banner->{$_}>$p->{$_})")
      if $p->{$_} && $banner->{$_}>$p->{$_};
  }
#  fatal("No access for this position ($position)")
#    if getUser()->Get('id')==1873 && $position=~/left/;

  return 1;
}

sub ListPositions {
  my @p = qw(top bottom splash middle right01 right02 left01 left02 left03 left04 left05 left06 left07 left08 left09 left10 left11 left12);
  my @pos;
  foreach (@p) {
    my $h = {name=>$_};
    $h->{size}=70000;
    if ($_ eq 'top' || $_ eq 'bottom' || $_ eq 'middle') {
      ($h->{width},$h->{height})=(728,90);
    } elsif (/^splash/) {
      ($h->{width},$h->{height})=(640,480);
    } elsif (/^right/) {
      ($h->{width},$h->{height})=(200,200);
      $h->{size}=60000;
    } else {
      ($h->{width},$h->{height})=(120,90);
      $h->{size}=50000;
    }
    push @pos,$h;
  }
  return @pos;
}


sub ListActivePositions {
  my $self = shift;
  my $res = $self->{db}->
    SuperSelectAndFetchAll(qq(select position, banner.*
                              from banners_display
                              left join banner on banners_display.banner_id=banner.id));
  my %pos;
  foreach (@$res) {
    $pos{$_->{position}}=[] unless $pos{$_->{position}};
    push @{$pos{$_->{position}}},$_;
  }
  return \%pos;
}



sub ListBanners {
  my ($self,$variety) = @_;
  my (@w,@b);
  if ($variety && keys %$variety) {
    foreach (keys %$variety) {
      push @w,"$_=?";
      push @b,$variety->{$_};
    }
  }
  unless (getUser()->HasAccess('banner_admin')) {
    push @w,"user_id=?";
    push @b,getUser()->Get('id');
  }
  my $w = join(' and ',@w);
  $w=" and $w" if $w;
  my $list = $self->{db}->SuperSelectAndFetchAll("select * from banner where is_removed='f' $w order by create_time desc",@b);
  foreach (@$list) {
    my $r = $self->{db}->
      SuperSelectAndFetch("select count(*) as count, sum(counter) as counter from banners_display where banner_id=?",
                          $_->{id});
    if ($r && $r->{count}) {
      $_->{counter}+=$r->{counter};
    }
  }
  return $list;
}

# user_id
# file
# position
# type
# width
# height
# * rank
# * date_from
# * date_to

sub CreateBanner {
  my ($self,$h) = @_;
  $h->{rank}=1;
  $h->{user_id}=getUser()->Get('id');
  $h->{type} = $h->{file}=~/\.swf$/i ? 'flash' : 'pic';
  my $res = $self->{db}->Insert('banner',$h);
  return $res;
}

sub GetBanner {
  my ($self,$id) = @_;
  my $banner = $self->{db}->SuperSelectAndFetch('select * from banner where id=?',$id);
  $self->CheckAccess($banner);

  $banner->{display} = $self->{db}->SuperSelectAndFetchAll('select * from banners_display where banner_id=?',$id);
  $banner->{all_counters}=$banner->{counter};
  if ($banner->{display}) {
    foreach (@{$banner->{display}}) {
      $banner->{all_counters}+=$_->{counter};
    }
  }
  return $banner;
}


sub UpdateBannerCounter {
  my ($self,$id) = @_;
  # TODO проверять условия показа баннеры и в случае чего - отклонять его, заносить в архив и тп
  $self->{db}->SuperSelect(qq(update banners_display set
                 counter = counter + 1,  last_time = current_timestamp
                 where id=?),$id);
  #             ranker = 100*(counter+1)/(rank*extract(epoch from (current_timestamp - date_from)))
  $self->{db}->Commit();
}

# sub ParseCookie_old {
#   my ($self,$cookie) = @_;
#   #  print STDERR "Parse cookie: $cookie\n";
#   return {} unless $cookie;
#   my $value = $cookie->value();
#   my %bc;
#   my @a = split('a',$value);
#   foreach (@a) {
#     my ($id,$count,$time)=split('-',$_);
#     $bc{$id}={count=>$count,time=>$time};
#   }
#   return \%bc;
# }

sub ParseCookie {
  my ($self,$cookie) = @_;
  #  print STDERR "Parse cookie: $cookie\n";
  return {} unless $cookie;
  my $value = $cookie->value();
#  print STDERR "Cookie is: $value\n";
  my %bc = split('-',$value);
#  print STDERR "Parsed is ".join(',',map {"$_=$bc{$_}"} keys %bc)."\n";
  # Очистим куки от всякой требухи
  my %ls;
  foreach (keys %bc) {
    $ls{$_}=$bc{$_} if exists $self->{positions}->{$_};
  }
  return \%ls;
}


sub UnparseCookie {
  my ($self) = @_;
  my $str = join('-',map {"$_-$self->{last_showed}->{$_}"} keys %{$self->{last_showed}});
#  print STDERR "Unparse Cookie: $str\n";
  return $str;
}


# sub UnparseCookie_old {
#   my ($self) = @_;
#   return join('a',map {"$_-$self->{bc}->{$_}->{count}-$self->{bc}->{$_}->{time}"} keys %{$self->{bc}});
# }


# ip - ip пользователя или берётся из setting
# session - номер сессии пользователя
# time - время или берётся today()
# position - искомая позиция баннера: top, left и тд
# site - площадка, на которой показывается баннер
#  $h->{ip} ||= setting('uri')->{remote_ip};
#  $h->{time} ||= today();

sub SetCookieToProcessor {
  my $self = shift;
  my $c = new CGI::Cookie(-name=>$self->{name},
                          -expires => '+30d',
                          -value=>$self->UnparseCookie(),
                          -path=>'/',

                         );
#  print STDERR "Cookie to set: $c\n";
  $self->{processor}->addCookie($c);
}



=pod

  create table banner (
                       id SERIAL primary key not null,
                       file varchar(255) unique,
                       user_id integer, -- кто загрузил баннер
                       date_from timestamp not null default current_timestamp,
                       date_to timestamp,
                       rank integer not null default 1, -- рейтинг от 1 до 100, чем выше, тем кратно чаще показывается

                       ranker bigint not null default 0, -- рейтингователь на текущую дату
                       -- по сути это колличество показов в секунду поделенное на рейтинг
                       -- таким образом чем меньше эта цифра тем чам будет выбираться этот баннер
                       -- и чем чаще он будте отображаться, тем больше будет эта цифра

                       create_time timestamp not null default current_timestamp,
                       is_active boolean not null default 'f',
                       is_removed boolean not null default 'f',

                       type varchar(10) not null, -- flash, gif etc

                       link varchar(255),

                       last_time timestamp,

                       size bigint not null,
                       width integer not null,
                       height integer not null,
                       counter bigint not null default 0,
                       comment varchar(255)
                      );

create table banners_log (
                          counter bigint not null default 0,
                          position varchar(100) not null,
                          date_from date not null,
                          date_to date not null default now(),
                          banner_id integer not null,
                          active_user_id integer, -- кто поставил баннер
                          deactive_user_id integer, -- кто снял
                          foreign key (banner_id) references banner (id)
                         );

 create table banners_display (
                               id SERIAL primary key not null,
                       user_id integer, -- кто поставил баннер
                               create_time timestamp not null default current_timestamp,
                               last_time timestamp,

                               date_to date,

                       link varchar(255),

                               file varchar(255) not null,
                               type varchar(10) not null default 'flash', -- flash, gif etc
                               position varchar(10) not null default 'top', -- top, left etc
                               width integer not null,  height integer not null,

                               counter bigint not null default 0,

                                banner_id integer not null,
                                unique (banner_id,position),
                                foreign key (banner_id) references banner (id)
                                on delete cascade
                               on update cascade
                      );
create index ndx_display_file on banners_display (file);

create index banner_ranker on banners_display (last_time);


=cut

1;
