package dpl::Context;
use strict;
use Exporter;
#use dpl::Log;
use dpl::Error;
use Date::Handler;
use base qw(Exporter);

use vars qw(
	    @EXPORT
            $context
            $user
            $setting
            $SUBSYSTEM
	    %SETTING
            $tt
            $st
	   );

@EXPORT = qw(getSettings
             getContext
             setUser
             getUser
             setting
             context
             directory
             CheckForm
             setContext);


sub st {
  my ($s,$o,$desc) = @_;
#  print STDERR "S: $s, $o\n";
  my $c = [ Time::HiRes::gettimeofday() ];
  my $a =Time::HiRes::tv_interval($tt, $c)*100;
  my $b = $o ? Time::HiRes::tv_interval($o, $c)*100 : '-';
  $a=~s/\..*//;
  $b=~s/\..*//;
  while (length($s)<8) {
    $s.=' ';
  }
#  print STDERR "$st: $s\t$b\t$a\t$desc\n";
#  $told=$c;
}

sub st_start {
  $tt = [ Time::HiRes::gettimeofday() ];
  # $told=$tt;
  $st=shift;
  $st=~s/.+\(0x(.+)\).*/$1/;
  st('start');
}

sub Init {
  my ($subsystem,$c) = @_;
  $SUBSYSTEM=$subsystem;
  dpl::Error::fatal("Subsystem $subsystem is not defined")
    unless exists $SETTING{$SUBSYSTEM};# && $CONTEXT{$SUBSYSTEM};
  $setting=\%{$SETTING{$SUBSYSTEM}};
  $context=$c || {};
  $context = bless $context, 'dpl::Context';
#   st_start()
#     unless $st;
  #\%{$CONTEXT{$SUBSYSTEM}};
  #  if ($c) {
  #    foreach (keys %$c) {
  #      $context->{$_}=$c->{$_};
  #    }
  #  }
}

sub SetMainMenu {
  my ($self,$mm) = @_;
  return $self->{mainmenu}=$mm;
}

sub GetMenuItem {
  my ($self,$key,$value) = @_;
  foreach (@{$self->{mainmenu}}) {
    return $_ if $_->{$key} eq $value;
  }
  return undef;
}

sub Deinit {
  $setting=undef;
  $context=undef;
  $SUBSYSTEM=undef;
}

sub getSettings {
  return $setting;
}

sub getContext {
  return $context;
}

sub setting {
  my $key = shift;
  return @_ ? $setting->{$key}=shift : $setting->{$key};
}

sub context {
  my ($key,$subkey) = @_;
  return $subkey ? $context->{$key}->{$subkey} : $context->{$key};
}

sub setContext {
  my ($key, $value) = (shift,shift);
  if (@_) {
    $context->{$key}->{$value}={} unless $context->{$key}->{$value};
    return $context->{$key}->{$value} = shift;
  } else {
    return $context->{$key} = $value;
  }
}

sub setUser { setContext('user_object',@_); }
sub getUser { context('user_object'); }

sub directory {
  my $name = shift;
  my $no_root = shift;
  return setting('dir')->{$name} if $no_root;
  my $root = setting('dir')->{root} || fatal("Не установлен корневой каталог ($name)");
  return $root if $name eq 'root';
  my $dir = setting('dir')->{$name};
  return $dir=~/^\// ? $dir : $root.$dir;
}


1;
