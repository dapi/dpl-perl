package dpl::Web::View;
use strict;
use Exporter;
use CGI;
use dpl::Error;
use dpl::Log;
use dpl::XML;
use dpl::Base;
use dpl::Context;
use vars qw(@ISA);
@ISA = qw(dpl::Base);

sub init {
  my ($self,$tnode,$vnode) = @_;
  $self->{vnode} = $vnode;
  $self->{tnode} = $tnode;
  return $self;
}


sub getOption {
  my ($self,$name,$data) = @_;
  return $self->Interpolate($data->{options}->{$name},$data) if defined $data->{options}->{$name};
  my $node=$self->{tnode}->findnodes("./$name")->pop();
  return $self->Interpolate(xmlText($node),$data) if $node;
  $node=$self->{vnode}->findnodes("./$name")->pop();
  return $self->Interpolate(xmlText($node),$data) if $node;
  #  dpl::Error::fatal("Option is not defined: $name")
  #      unless $not_mand;
  return undef;
}

sub getOptions {
  my ($self,$name,$data) = @_;
  my %header;

  foreach ($self->{vnode}->findnodes("./$name/node()")) {
    my $type = $_->nodeType();
    next unless $type==1; # next if this is text or comment
    my $name=xmlDecode($_->nodeName());
    $header{$name}=$self->Interpolate(xmlText($_),$data);
  }
  foreach ($self->{tnode}->findnodes("./$name/node()")) {
    my $type = $_->nodeType();
    next unless $type==1; # next if this is text or comment
    my $name=xmlDecode($_->nodeName());
    $header{$name}=$self->Interpolate(xmlText($_),$data);
  }
  return $data->{$name} ? {%header,%{$data->{$name}}} : \%header;
}


sub getAttribute {
  my ($self,$attr,$data,$def)=@_;
  return $data->{$attr}
    if defined $data->{$attr};
  return $self->Interpolate(xmlDecode($self->{tnode}->getAttribute($attr)),$data)
    if $self->{tnode}->hasAttribute($attr);
  return $self->Interpolate(xmlDecode($self->{vnode}->getAttribute($attr)),$data)
    if $self->{vnode} &&
      $self->{vnode}->hasAttribute($attr);
  return $def ? $def : undef ;#dpl::Error::fatal("View attribute is not defined: $attr");
}


sub Interpolate {
  my ($self,$url,$data) = @_;
  $url=~s/([=?]?)\$\{([a-zA-Z0-9_:]+)\}/$self->_parseParam($1,$2,$data)/ge;
  # foreach (split(/\|/,$url)) {
  #   $_=uri()->home().$_
  #     if /^\?/||/^[^\/:]+\//;
  #   next unless $_;
  #   s/\&/\?/
  #     if !/\?/;
  #   if (uri()->current() eq $_) {
  #     log_warn(25);
  #     $_=uri()->home();
  #   }
  #   $rurl=$_;
  #   last;
  return $url;
}

sub _parseParam {
  my ($self,$encode,$name,$data)=@_;
  my $value;
  my $check_lp=0;
#  if ($name eq 'referer') {
#    $check_lp=1;
#    $value=uri()->referer();
#  } elsif ($name eq 'current') {
#    $check_lp=1;
#    $value=uri()->current();
#  } elsif ($name eq 'home') {
#    $value=uri()->home();
#  } elsif ($name eq 'langhome') {
#    $value=uri()->langhome();
#  } elsif ($name eq 'result') {
#    $value=$result;
#  } elsif ($name=~/^param:(.+)$/){
#    $value=param($1);
#  } elsif ($name=~/^context:(.+)$/){
  #    $value=context($1);
  my $cgi;
  if ($name=~/^uri:(.+)$/) {
    $value = setting('uri')->{$1};
  } elsif ($name=~/^data:(.+)$/){
    $value=$data->{$1};
  } elsif ($name=~/^param:(.+)$/){
    $cgi=new CGI unless $cgi;
    $value=$cgi->param($1);
  } elsif ($name=~/^result:(.+)$/){
    $value= ref($data->{result}) eq 'HASH' ?  $data->{result}->{$1} : undef;
  } elsif ($name=~/^result$/){
    $value= $data->{result};
  }
  #URI::Escape::uri_escape-кодируетвсе
  # Енкодить надо там, где применяется
  #  $value='='.URI::Escape::uri_escape($value)	#кодируетневсе,напримероставляет&,кажется
 #   if $encode;
  #  if ($check_lp) {
  #	die'checkloginandpasswordparameters';
  #	$value=~s/[\&|\?]login=([^&]*)//;
  #	$value=~s/[\&|\?]password=([^&]*)//;
  #  }
  return $value;
}

1;



1;
