package dpl::Web::Handler::SiteSelector;
use strict;
use dpl::Error;
use dpl::Config;
use dpl::System;
use dpl::XML;
use dpl::Log;
use dpl::Web::Handler;
use dpl::Context;
use Apache2::Const;
use Apache2::Connection ();
use Apache2::URI;
use APR::URI;
use vars qw(@ISA);
use Exporter;
@ISA = qw(Exporter
	  dpl::Web::Handler);

sub init {
  my ($self,$r) = @_;
  $self->SUPER::init($r);
  $self->{config}=config()->root();
  $self->initURI();
  return $self;
}

sub initURI {
  my $self = shift;
  my %uri;
  # my $remote_ip = $apr=~/Fake/ ? '127.0.0.1'
  my $ip = $self->{r}->headers_in()->{'X-Forwarded-For'} ||
    $self->{r}->connection()->remote_ip();
  my @i = split(/\,\s+/,$ip);
  $uri{remote_ip} = pop @i;
  $uri{referer} = $self->{r}->headers_in()->{'Referer'};
  $uri{user_agent} = $self->{r}->headers_in()->{'User-Agent'};
  my $xurl = $self->{r}->headers_in()->{'X-URL'};

  if ($xurl) {

    $xurl="http://$xurl" unless $xurl=~/^http:\/\//;
    $uri{xurl}=$xurl;
    $uri{current} = APR::URI->parse($self->{r}->pool,$xurl);
    $uri{current}->port(undef) if $uri{current}->port()==80;
  } else {
    my $server = $self->{r}->parsed_uri;
    $server->hostname($self->{r}->get_server_name());
    $server->port($self->{r}->get_server_port())
      if $self->{r}->get_server_port()!=80;
    $server->scheme('http');
    $uri{current} = $server;
    $uri{xurl}=$server;
  }
  setting('uri',\%uri);
}

sub registerHandlers {
  my $self = shift;
  my $r = $self->{apache_request_rec};
  #  !$r->set_handlers(PerlAccessHandler => [$self->GetHandler('Access')]);
  #  $r->set_handlers(PerlAuthenHandler => [$self->GetAuthenHandler($action)]);
  #  $r->set_handlers(PerlAuthzHandler => [$self->GetAuthzHandler($action)]);

  # С этой строкой не работает если из эксекутf хочется послать decline - выходит страница not found;
  #  $r->handler("perl-script");

  # Если не запускается, проверить не стоит ли AddHandler strip-meta-http .htm .html
  # и запрашиваемый документ *.html
  #  $r->set_handlers(PerlHandler => [$handler]); #$handler

#!  my $cleanup = $self->GetHandler('Cleanup');
#!  $r->register_cleanup($cleanup)
#!    if $cleanup;
  # Без этой строки не вызываются никакие устанавливаемае здесь хендлеры кроме очистки в случае
  # виртуальных хостов как на орионет.ру


  #!$r->set_handlers(PerlHeaderParserHandler => undef);


  #$r->set_handlers( PerlPostReadRequestHandler => undef);

}

sub handler_Access {
  logger()->debug('Access handler');
  return Apache2::Const::OK;
}

sub lookup {
  my $self = shift;
  setting('handler',$self);
  my $s = $self->lookupSite(setting('uri')->{current}->unparse) || return undef;
  setting('uri')->{home} = $s->{home};
  setting('uri')->{path} = $s->{path};
 # print STDERR "$s->{class}->instance($s->{name},$s->{home})\n";
  $self->{site} = $s->{class}->instance($s->{name},$s->{node},$s->{home},$s->{path}) ||
    $self->fatal("Can't init site: $s->{site} ($s->{class})");
  return $self->{site}->lookup($s->{path});
}

sub lookupSite {
  my ($self,$url) = @_;
  #  logger()->debug("lookup site: $url");
#  print STDERR "lookup site: $url\n";

  my $node = $self->{config}->
    findnodes("./sites/site[starts-with('$url',\@home)]")->pop()
      || return undef;

  my $home = xmlDecode($node->getAttribute('home'));
#  print STDERR "looked: $home\n";
  my $path = substr($url,length($home));
  my $name  = $node->hasAttribute('name') ? xmlDecode($node->getAttribute('name')) : 'default';
  my $class = $node->hasAttribute('class') ?  xmlDecode($node->getAttribute('class')) :
    ($node->parentNode()->hasAttribute('class') ? xmlDecode($node->parentNode()->getAttribute('class')) :
     $self->fatal("No site class is defined"));

# print STDERR "Site found: $name, home: $home, path: $path\n";
  return {class=> $class,
          name => $name,
	  node => $node,
          home => $home,
          path => $path
         };
}

sub execute {
  my $self = shift;
  #  logger()->debug('Execute site');
  $self->registerHandlers();
  my $result = $self->{site}->execute();
  dpl::Context::st('site');
  my $res = $self->{site}->show($result);
  dpl::Context::st('e_show');
  return $res;
}

sub deinit {
  my ($self,$is_ok) = @_;
#  print STDERR "SiteSelector: deinit\n";
  $self->{site}->deinit($is_ok) if $self->{site};
}


1;
