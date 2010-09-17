package dpl::System;
use strict;
use Exporter;
#use dpl::Log;
use Date::Handler;
use Date::Handler::Delta;
use dpl::Context;
use dpl::Config;
use dpl::XML;
use dpl::Error;
#use dpl::Web::Handler;
use Date::Handler;
use dpl::DataType::Date;
use Time::HiRes;
use base qw(Exporter);
use vars qw(@EXPORT
            %TIMERS
            $VERSION);

( $VERSION ) = '$Revision: 1.7 $ ' =~ /\$Revision:\s+([^\s]+)/;

# feauters
# processors

@EXPORT=qw(today
           startTimer
           stopTimer);

sub today { return context('today') || setToday(); }

sub startTimer {
  my $name = shift;
  $TIMERS{$name}=[ Time::HiRes::gettimeofday() ];
}

sub stopTimer {
  my ($name,$desc) = @_;

  if ($TIMERS{$name}) {
    dpl::Context::st($name,$TIMERS{$name},$desc);
    #    $i=~s/\..*//;
    #    my $handler = setting('handler');
    # dpl::Web::Handler не рабоатет не из под mod_perl
#    my $handler = $dpl::Web::Handler::st;
#    print STDERR "ST $handler: Timer ($name): $i $desc\n" if $i>=0.01;
#    return $i;
  } else {
    print STDERR "No such timer to stop: $name\n";
    return undef;
  }

}

sub setToday {
  my $root = shift;
  unless ($root) {
    my $config = config();
    if ($config) {
      $root=$config->root();
    } else {
      return setContext('today',new dpl::DataType::Date({date=>time()}));
    }
  }
  my %h=(date=>time(),
         locale=>'ru_RU.KOI8-R'); # TODO в конфиг
  my $tz = xmlText($root,'timezone'); #  $h{time_zone} = 'GMC';
  $h{time_zone} = $tz;
  return setContext('today',new dpl::DataType::Date(\%h));
}


# TODO Сделать reinit с чтением конфига и тп. применяется при loop в openbill

sub Define  {
  my ($subsystem,$config_file)=@_;
  fatal("Subsystem '$subsystem' is already defined")
    if defined $dpl::Context::SETTING{$subsystem};# ||  defined $dpl::Context::CONTEXT{$subsystem};
  $dpl::Context::SETTING{$subsystem}={};
#  $dpl::Context::CONTEXT{$subsystem}={};
  dpl::Context::Init($subsystem);
  setting('xml.reload',1);
  setting('xml.encode','koi8-r');
  setting('subsystem',$subsystem);
  setting('config_file',$config_file);
  dpl::Config::Init() if $config_file;
}


1;
