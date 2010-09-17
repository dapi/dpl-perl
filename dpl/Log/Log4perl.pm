package dpl::Log::Log4perl;
use strict;
use dpl::Base;
use base qw(dpl::Base);
use dpl::Context;
use Log::Log4perl;

sub init {
  my ($self) = @_;

  my $file = setting('logger_config') || return undef;
#  Log::Log4perl::init($file);
  Log::Log4perl::init_and_watch($file,10);
  #  $SIG{__DIE__} = sub {
  #    $Log::Log4perl::caller_depth++;
  #    my $log = Log::Log4perl::get_logger();
  #    $log->fatal('DIE',@_);
  #    exit 1;
  #  };
  return Log::Log4perl::get_logger();
}

1;
