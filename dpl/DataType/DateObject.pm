package dpl::DataType::DateObject;
use strict;
use locale;
use POSIX qw(locale_h);
use dpl::System;
use dpl::Error;
use dpl::System;
use Date::Handler;
use Date::Handler::Delta;
use Date::Parse;
use Date::Language;
use Number::Format qw(:subs);
use Exporter;
use vars qw(@ISA
            @MONTHS
            @WEEK_DAYS
            @EXPORT);
@MONTHS=qw(Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь);
@WEEK_DAYS=qw(понедельник вторник среда четверг пятница суббота воскресенье);

@ISA=qw(Exporter Date::Handler);
#@EXPORT=qw(ParseDateTime
#           ParseDate);

sub new {
  my $self = shift;
  my $p = shift;
  if (ref($p)=~/HASH/) {
    $p->{time_zone} = 'Europe/Moscow'
      unless defined $p->{time_zone};
    $p->{locale}="ru_RU.KOI8-R"
      unless defined $p->{locale};
  }
  return $self->SUPER::new($p,@_);
}

sub FromSOAP {
  my ($self,$value) = @_;
  return undef unless $value;
  my $time = str2time($value) || fatal("Не могу распознать дату из SOAP: $value");
#  print STDERR "FromSOAP: $value,$time\n";
  return $self->new({
                     date=>$time, # TODO locale ииз конфига, time_zone из параметров переданных сервером или
                    });
}

sub ToSOAP {
  die 'ToSoap is not realized';
}

sub TimeFormat {
  my ($self,$format) = (shift,shift);
  $format = $self->SUPER::TimeFormat($format,@_);
  $format=~s/\%K/$self->DaysInMonth()/eg;
  return $format;
}

#te->DaysInMonth
sub ParseDateTime {
  my $value = shift;
  return undef unless $value;
  if ($value eq 'today') {
    return dpl::System::today();
  } elsif (my ($year,$month,$day,$hour,$minut,$s,$seconds)
           =($value=~/^(\d\d\d\d)[.\-\/](\d\d)[.\-\/](\d\d) (\d\d):(\d\d)(:(\d\d))?/)) {
    return dpl::DataType::DateTime->new({ date => {year=>$year,
                                                   month=>$month,
                                                   day=>$day,
                                                   hour=>$hour,
                                                   min=>$minut,
                                                   sec=>$seconds}});    # TODO time_zone веьде перевезти в конфиг
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY.MM.DD HH:MM:SS");
  }
}

sub ParseTime {
  my $value = shift;
  return undef unless $value;
  if ($value eq 'today') {
    return dpl::System::today();
  } elsif (my ($hour,$minut,$s,$seconds)
           =($value=~/^(\d\d):(\d\d)(:(\d\d))?/)) {
    return dpl::DataType::DateTime->new({ date => {hour=>$hour,
                                                   min=>$minut,
                                                   sec=>$seconds}});    # TODO time_zone веьде перевезти в конфиг
  } else {
    fatal("Неверно указана дата '$value', надо в формате HH:MM:SS");
  }
}

sub ParseDate {
  my $value = shift;
  return undef unless $value;
  if ($value eq 'today') {
    return dpl::System::today();
  } elsif (my ($year,$month,$day,$hour)
           =($value=~/^(\d\d\d\d)[.\-\/](\d\d)[.\-\/](\d\d)/)) {
    return dpl::DataType::Date->new({ date => {year=>$year,
                                               month=>$month,
                                               day=>$day,
                                               hour=>0,
                                               min=>0,
                                               sec=>0}});    # TODO time_zone веьде перевезти в конфиг
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY.MM.DD");
  }
}

sub GetMonthsDates {
  my $value = shift;
  my $d1 = dpl::DataType::Date->
    new({ date => {year=>$value->Year(),
                   month=>$value->Month(),
                   day=>1,
                   hour=>0, min=>0, sec=>0}});
  my $d2 = dpl::DataType::Date->
    new({ date => {year=>$value->Year(),
                   month=>$value->Month(),
                   day=>$value->DaysInMonth(),
                   hour=>23, min=>59, sec=>59}});
  return ($d1,$d2);
}



sub ParseMonth {
  my $value = shift;
  if ($value eq 'today') {
    return dpl::System::today();
  } elsif (my ($year,$month)
           =($value=~/^(\d\d\d\d)[.\-\/]?(\d\d)/)) {
    my $date =
      dpl::DataType::Date->new({ date => {year=>$year,
                                          month=>$month,
                                          day=>1,
                                          hour=>0,
                                          min=>0,
                                          sec=>0}});    # TODO time_zone веьде перевезти в конфиг
    return $date + ($date->DaysInMonth()-1)*24*60*60;
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY-MM");
  }
}


sub human {
  my ($date,$no_time) = @_;
  return '' unless $date;
  my $today = dpl::System::today();
  use locale;
  setlocale(LC_CTYPE,"ru_RU.KOI8-R");
  my $time = $date->TimeFormat('%H:%M');
  my $today_day = new dpl::DataType::Date({ date => {
                                               year => $today->Year(),
                                               month => $today->Month(),
                                               day => $today->Day(),
                                              },
                                      time_zone => 'Europe/Moscow',
                                      locale=>"ru_RU.KOI8-R"
                                    });
  my $date_day = new dpl::DataType::Date({ date => {
                                              year => $date->Year(),
                                              month => $date->Month(),
                                              day => $date->Day(),
                                             },
                                     time_zone => 'Europe/Moscow',
                                     locale=>"ru_RU.KOI8-R"
                                   });

  my $day = 24*60*60;
  my $human;
  my $b = $today_day>$date_day;
  my $d = $today_day-$date_day;

  my $seconds = $d->Seconds();
  my $days = $seconds/$day;
  #print STDERR "date ($no_time): $today_day-$date_day=$d, $b, $seconds, $days\n";
  if ($days>2 || $days<-2) {
    $human=$date_day->Year()==$today_day->Year() ?
      $date->TimeFormat('%e %B') :
        $date->TimeFormat('%e %B %Y года');
  } elsif ($days>1) {
      $human="позавчера";
  } elsif ($days && $days>0) {
      $human="вчера";
  } elsif ($days==-1) {
    $human="завтра";
  } elsif ($days==-2) {
    $human="послезавтра";
  } else {
    $human="сегодня";
  }
  unless ($no_time) {
    $human.=" в $time";
  }
  $human=~s/^ //;
#  print STDERR "human: $human\n";
#  die $seconds
  return $human;

}

sub pass {
  my $date = shift;
  return '' unless $date;
  my $today = shift || dpl::System::today();
  use locale;
  setlocale(LC_CTYPE,"ru_RU.KOI8-R");
#  my $time = $date->TimeFormat('%H:%M');
#   my $today_day = new dpl::DataType::Date({ date => {
#                                                year => $today->Year(),
#                                                month => $today->Month(),
#                                                day => $today->Day(),
#                                                hour => $today->
#                                               },
#                                       time_zone => 'Europe/Moscow',
#                                       locale=>"ru_RU.KOI8-R"
#                                     });
#   my $date_day = new dpl::DataType::Date({ date => {
#                                               year => $date->Year(),
#                                               month => $date->Month(),
#                                               day => $date->Day(),
#                                              },
#                                      time_zone => 'Europe/Moscow',
#                                      locale=>"ru_RU.KOI8-R"
#                                    });

  my $day = 24*60*60;
  my $human;
  my $d = $today-$date;
  my $seconds = $d->Seconds();
  my $days = $seconds/$day;
  $days=~s/[.,].*//;
  $days=0 if $days<1;
  my $hours = round(($seconds-$days*$day)/(60*60),0);
  $hours=~s/[.,].*//;
  my $minuts = round(($seconds-$hours*60*60)/60,0);
  #  print STDERR "-$date $seconds $s\n";
  if ($days>1) {
    return "$days дн.";
  } elsif ($days) {
    $human="сутки и $hours час.";
  } elsif ($hours) {
    $human="$hours час. $minuts мин.";
  } else {
    $human="$minuts мин.";

  }
  $human=~s/^ //;
#  die $seconds
  return $human ;

}

sub WeekDayName {
  my $self = shift;
  my $w = $self->WeekDay();
  return $WEEK_DAYS[$w-1];
}

sub MonthName {
  my $self = shift;
  return $MONTHS[$self->Month()-1];
}


sub NextDay {
  my $self = shift;
  my $year = $self->Year();
  my $month = $self->Month();
  my $day = $self->Day();
  $day++;
  if ($day>$self->DaysInMonth()) {
    $day=1;
    $month++;
    if ($month>12) {
      $month=1;
      $year++;
    }
  }
  my $date = new
    dpl::DataType::Date({ date => {
                                   year => $year,
                                   month => $month,
                                   day => $day,
                                  },
                          time_zone => 'Europe/Moscow',
                          locale=>'ru_RU.KOI8-R'
                        });

  return $date;
}


sub PrevDay {
  my $self = shift;
#   my $year = $self->Year();
#   my $month = $self->Month();
#   my $day = $self->Day();
#   $day--;
#   if ($day<0) {
# #    $day=;
#     $month--;
#     if ($month<1) {
#       $month=1;
#       $year--;
#     }
#     $self->DaysInMonth()
#   }
#   my $date = new
#     dpl::DataType::Date({ date => {
#                                    year => $year,
#                                    month => $month,
#                                    day => $day,
#                                   },
#                           time_zone => 'Europe/Moscow',
#                           locale=>'ru_RU.KOI8-R'
#                         });

  return $self-24*60*60;
}


sub NextMonth {
  my $self = shift;
  return new
    dpl::DataType::Date({ date => {
                                   year => $self->Year(),
                                   month => $self->Month(),
                                   day => $self->DaysInMonth,
                                  },
                          time_zone => 'Europe/Moscow',
                          locale=>'ru_RU.KOI8-R'
                        })->NextDay();
}



sub StartMonth {
  my $self = shift;
  return new
    dpl::DataType::Date({ date => {
                                   year => $self->Year(),
                                   month => $self->Month(),
                                   day => 1,
                                  },
                          time_zone => 'Europe/Moscow',
                          locale=>'ru_RU.KOI8-R'
                        });
}



sub IsToday {
  my $self = shift;
  my $today = dpl::System::today();
  return $self->TimeFormat('%D') eq $today->TimeFormat('%D');
}

sub IsTomorrow {
  my $self = shift;
  my $today = dpl::System::today()->NextDay();
  return $self->TimeFormat('%D') eq $today->TimeFormat('%D');
}

sub IsPassed {
  my $self = shift;
  return $self<dpl::System::today();
}



1;
