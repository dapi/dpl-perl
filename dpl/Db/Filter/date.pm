package dpl::Db::Filter::date;
use strict;
use locale;
use Date::Parse;
use Date::Language;
#use Date::Handler;
#use Date::Handler::Delta;
use dpl::DataType::DateTime;
use dpl::DataType::Time;
use dpl::DataType::Date;
use dpl::Error;
use dpl::XML;
use vars qw(@ISA);
@ISA = qw(Exporter dpl::Base);

sub init {
  my ($self) = @_;

  $self->{from_sql}={
                     input=>$self->getParam('from_sql/input'),
                     output=>$self->getParam('from_sql/output'),
                    };

  $self->{to_sql}={
                   input=>$self->getParam('to_sql/input'),
                   output=>$self->getParam('to_sql/output'),
                  };

  return $self;
}

sub getParam {
  my ($self,$n) = @_;
  my $node = $self->{config}->findnodes("./$n")->pop();
  return '' unless $node;
  my $locale = $node->hasAttribute('locale') ? xmlDecode($node->getAttribute('locale')) : undef;
  my $ifnull = $node->hasAttribute('ifnull') ? xmlDecode($node->getAttribute('ifnull')) : undef;
  my $lang = $node->hasAttribute('lang') ? xmlDecode($node->getAttribute('lang')) : undef;
  my $timezone = $node->hasAttribute('timezone') ? xmlDecode($node->getAttribute('timezone')) : undef;
  my $shift = $node->hasAttribute('shift') ? xmlDecode($node->getAttribute('shift')) : '000';
  my $class = $node->hasAttribute('class') ? xmlDecode($node->getAttribute('class')) : 'dpl::DataType::DateTime';
  return {locale=>$locale, ifnull=>$ifnull,
          class=>$class,
          lang=>$lang, shift=>$shift,
          timezone=>$timezone, format=>xmlText($node)};
}

# From Internal to SQL

sub ToSQL {
  my ($self,$value)=@_;
#  die $self->{to_sql}->{output}->{ifnull};
  #  die 2;
  return $self->{to_sql}->{output}->{ifnull} || $value if !$value || $value=~/^0000/;
  my $fi = $self->{to_sql}->{input}->{format};
  my $li = $self->{to_sql}->{input}->{locale};
  my $itz = $self->{to_sql}->{input}->{timezone};
  my $fo = $self->{to_sql}->{output}->{format};
  my $lo = $self->{to_sql}->{output}->{locale};
  my $otz = $self->{to_sql}->{output}->{timezone};
  fatal("Локаль входного параметра в SQL не поддерживается")
    if $li;
  fatal("Входной формат в SQL может быть тольло object")
    unless $fi eq 'object';
  my $object;
  if (UNIVERSAL::isa($value,'Date::Handler')) {
    my $locale = $value->Locale();
    $object = $value+0;
    $object->SetLocale($locale);
    $value->SetLocale($locale);
  } elsif ($value=~/^\d+$/) {

    $object = $self->{to_sql}->{output}->{class}->new({date=>$value,
                                                       time_zone=>$itz,
                                                      });
  } elsif ($value eq 'now()' || $value eq 'now') {
    return 'now()';
  } else {
    my $lang = Date::Language->new('Russian');
    $value = $lang->str2time($value) || fatal("Не могу распознать $value");
    fatal("Не указан input timezone ($self->{name})") unless  $itz;
    $object = $self->{to_sql}->{output}->{class}->new({date=>$value,
                                                       time_zone=>$itz});
  }
  $object->SetLocale($lo) if $lo;
  $object->TimeZone($otz) if $otz;
  return $object->TimeFormat($fo);
}

# From SQL to string

sub FromSQL {
  my ($self,$value)=@_;
  return $value unless $value;
#  print STDERR "date: $value\n";
  my $fi = $self->{from_sql}->{input}->{format};
  my $li = $self->{from_sql}->{input}->{locale};
  my $langi = $self->{from_sql}->{input}->{lang};
  my $fo = $self->{from_sql}->{output}->{format};
  my $lo = $self->{from_sql}->{output}->{locale};
  my $otz = $self->{from_sql}->{output}->{timezone} || 'GMT';
  my $itz = $self->{from_sql}->{input}->{timezone} || 'GMT';
  $value=undef
    if $value eq '00000000000000' || $value=~/0000-00-00 00:00:00/ || $value=~/0000-00-00/;
#  print STDERR "data:$value\n";
  #  $value=~s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/$1-$2-$3 $4:$5:$6/;
  #  my $time = str2time($value,$self->{from_sql}->{input}->{shift}) || fatal("Can't parse sql date format: $value");
  #  fatal("Входной формат из sql не поддерживается")
  #    if $fi;
  #  my $value=~s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/$1-$2-$3 $4:$5:$6/;
  my $d=[];
  if (@$d=($value=~/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) or
      @$d=($value=~/^(\d{4})-(\d{2})-(\d{2})$/) or
      @$d=($value=~/^(\d{4})-(\d{2}-)(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(\.\d+)?$/)) {

  } elsif (@$d=($value=~/^(\d{2}):(\d{2}):(\d{2})$/)) {
    unshift @$d,(0,0,0);
  } elsif (@$d=($value=~/^(\d{2})(\d{2})$/)) {
    $d->[0]+=2000; # NOTE Возможно надо прибавлять другое число. Ошибка 2000. e2k
    push @$d,(1,0,0,0);
  } else {
    return undef unless $value;
    return undef;
    die "unimplemented: $value";
    #  TODO str2time глючит. Использует ZONE установленную где-то в системе неивзестно после чего
    my $lang = Date::Language->new('Russian');
    $d = $lang->str2time($value); #,$self->{from_sql}->{input}->{shift}
    fatal("Не опознан формат даты: $value")
      unless $d;
  }
  # TODO!!
  $d->[0]=2000 if $d->[0]==1970;
#  print STDERR "data: $d->[0], $itz, $li\n";
  my $object = $self->{from_sql}->{output}->{class}->
    new({date=>$d,
         time_zone=>$itz,
         locale=>$li});
  #  die "$object";
#  print STDERR "($itz,$li,$langi,$self->{from_sql}->{input}->{shift}) $value/$d -  ($otz,$lo) $object - ";
  $object->SetLocale($lo) if $lo;
  $object->TimeZone($otz) if $otz;
#  print STDERR " $object\n";
  if ($fo eq 'object') {
    return $object;
  } else {
    return $object->TimeFormat($fo);
  }
}

1;
