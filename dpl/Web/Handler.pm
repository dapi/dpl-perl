package dpl::Web::Handler;
use strict;
use mod_perl 1.99;
use Apache2::Const;
use Apache2::RequestUtil;
use Apache2::RequestRec;
use dpl::Context;
use dpl::Error;
use dpl::Log;
use Error qw(:try);
use Exporter;
use dpl::Base;
use Time::HiRes;
use vars qw(@ISA);
@ISA = qw(dpl::Base);

use vars qw($VERSION);

( $VERSION ) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;


sub declined {
  my ($self) = @_;
  if (ref($self)=~/Apache/) {
    $self->set_handlers(PerlHeaderParserHandler => [\&transHandler]);
  } else {
    $self->{apache_request_rec}->
      set_handlers(PerlHeaderParserHandler => [$self->GetHandler('HeaderParser')]);
  }
  return Apache2::Const::DECLINED;
}

sub GetHandler {
  my ($self, $handler_name) = @_;
  return $self->can("handler_$handler_name");
}

sub handler_HeaderParser {
  return Apache2::Const::DECLINED;      #  return -f shift->finfo ? DECLINED : NOT_FOUND;
}



sub handler {
  my ($class,$r)=@_;
  dpl::Context::st_start($r);
  my $res = $class->_handler($r);
  dpl::Context::st("finish");
#  print STDERR "\n\n";
  return $res;
}
sub _handler {
  my ($class,$r) = @_;
  # ??
  #  return declined($r) unless $r->is_inital_req();
  my $handler;
  return try {
    dpl::Context::st("_handler");
    #  return try {
    $handler = $class->
      instance($r->dir_config('subsystem') || $class->fatal("No subsystem is defined"),
               $r)
        || $class->fatal("Can't init handler");
    dpl::Context::st("_handler2");
    # $rc = $pr->run(@_);
    #  return ($rc != OK) ? $rc : $pr->status;
    my $res = $handler->lookup();
    dpl::Context::st('lookup',0,setting('uri')->{current}->unparse);
    return NOT_FOUND unless $res;
    $res=$handler->execute();
    return $res;
  } catch Error with {
    my $e = shift;
    print STDERR "Catch error: $e\n";
    #    apr()->custom_response(SERVER_ERROR,
    #			   awe::View::error::getPage($e->stringify)
    #   );
    #    return SERVER_ERROR;
    #    Error::throw($e);
    $handler->deinit(0)
      if $handler;
    return showError($r,$e->stringify);
  } otherwise {
    print STDERR "Catch error: Otherwise\n";
    $handler->deinit(0)
      if $handler;
    return showError($r,"UNKNOWN ERROR: $@");
  } finally {
    $handler->deinit(1)
      if $handler;
  };
  return Apache2::Const::SERVER_ERROR;
}

sub deinit {
#  print STDERR "handler: deinit\n";
}

sub init {
  my ($self,$r) = @_;
#  print STDERR "init handler";
  setContext('temp',{});
  dpl::Context::Init($self->{subsystem} = $self->{name},
                     {handler=>$self,
                      apr=>$self->{r}=$r});
  return $self;
}

sub showError {
  my ($r,$error)=@_;
  $error=~s/\n/<br>/g;
  $r->custom_response(SERVER_ERROR,
		      "<html><h1>web:Fatal Error</h1><code>$error</code></html>".' 'x500);
  return SERVER_ERROR;
}


1;
