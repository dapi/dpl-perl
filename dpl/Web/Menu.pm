package dpl::Web::Menu;
use strict;
use Exporter;
#use dpl::Log;
use dpl::Context;
use dpl::Error;
use Date::Handler;
use base qw(Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(SetMenu
             GetMenuItem);


sub SetMenu {
  my ($mm) = @_;
  return setContext('mainmenu',$mm);
}


sub GetMenuItem {
  return _findSubMenu(context('mainmenu'),@_);
}

sub _findSubMenu {
  my ($mm,$key,$value) = @_;
  foreach (@$mm) {
    return $_ if $_->{$key} eq $value;
    if ($_->{childs}) {
      my $res = _findSubMenu($_->{childs},$key,$value);
      return $res if $res;
    }
  }
  return undef;
}


1;
