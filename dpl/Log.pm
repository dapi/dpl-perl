package dpl::Log;
use strict;
use Exporter;
use dpl::Error;
use dpl::Base;
use dpl::Context;
use Log::Log4perl;
use vars qw(@ISA
	    @EXPORT);

@ISA = qw(Exporter
	  dpl::Base);

@EXPORT = qw(logger);

sub logger {
  my $name = shift || 'default';
  my $loggers = dpl::Context::context('loggers');

  unless ($loggers) {
    my $file = dpl::Context::setting('logger_config') || return undef;
    Log::Log4perl::init($file);
    dpl::Context::setContext('loggers',$loggers={});
  }
#  die Log::Log4perl::get_logger($name);
  $loggers->{$name} = Log::Log4perl::get_logger($name)
    unless $loggers->{$name};
  #  die $loggers->{$name} if $name eq 'sql';
  return $loggers->{$name};
}

1;
