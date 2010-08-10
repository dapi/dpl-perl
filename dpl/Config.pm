package dpl::Config;
use strict;
use dpl::Log;
use dpl::XML;
use dpl::Error;
use dpl::Context;
use dpl::Base;
use Error;
use Exporter;

use vars qw(@ISA
	    @EXPORT
	    $VERSION
	   );

@ISA = qw(Exporter
	  dpl::Base);

( $VERSION ) = '$Revision: 1.6 $ ' =~ /\$Revision:\s+([^\s]+)/;

@EXPORT = qw(config);

sub LoadXMLConfig {
  my ($self,$file,$subsystem) = @_;
  fatal('not implemented') unless $subsystem;
  $self->{includes}={};
  $self->{first_dir}=$file;
  $self->{first_dir}=~s/\/[^\/]+$/\//;
  $self->{root} = $self->loadXMLInclude($file,$subsystem);
  #die 1;#$self->{root}->toString();
   return $self->{root};
}

sub loadXMLInclude {
  my ($self,$file,$subsystem) = @_;
  $self->{includes}->{$file}=1;
  my $xml = xmlFile($file)
    || $self->fatal("Can't read xml include file: $file");
  $xml=$xml->documentElement();
  my $root = $subsystem
    ? $xml->findnodes("/xml/subsystem[\@name='$subsystem']")->pop()
      : $xml->findnodes("/xml")->pop();
  fatal("No node for this subsystem ($subsystem) in config file $file")
    unless $root;
  foreach my $node ($root->findnodes('./include')) {
    my $inc = xmlText($node);
    $inc="$self->{first_dir}$inc" unless $inc=~/\//;
    fatal("Loop includes detected: $inc from $file")
      if $self->{includes}->{$inc};
    my $include = $self->loadXMLInclude($inc)
      || fatal("Can't load XML include file: $inc");
    map {$root->appendChild($_)} $include->childNodes();
    $root->removeChild($node);
  }
#  print "------------\n";
#  print $root->toString();
#  print "------------\n";
  return $root;
}

sub config {
  return setting('config');
}

sub root {
  my $self = shift;
  return $self->{root};
}

sub Init {
  my $self = dpl::Config->new('default');
  $self->LoadXMLConfig(setting('config_file'),
                       setting('subsystem') || fatal('Subsystem is not defined'));
  fatal('There is already config')  if exists getSettings()->{config};
  getSettings()->{config}=$self;
  my $root = $self->root();
  setting('dir',getDirectories($root));
  my $f = xmlText($root,'./logger/config');
  $f=directory('etc').$f unless $f=~/\//;
  setting('logger_config',$f || fatal('Logger config is not defined'));
  return $self->root();
}


sub getDirectories {
  my $root = shift || config()->root();
  my %dir;
  foreach my $node ($root->findnodes('./directories/*')) {
    my $name = xmlDecode($node->nodeName());
    my $dir = xmlText($node);
    $dir="$dir/" unless $dir=~/\/$/;
    $dir{$name}=$dir;

    #   учитвать root  mkdir($dir) || fatal("Немогу создать директорию: '$dir'")  unless -d $dir;
  }
  return \%dir;
}




1;
