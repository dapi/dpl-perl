package $SYSTEM::Base;
use strict;
use dpl::Web::Processor::Access;
use dpl::Web::Session::JustUser;
use dpl::Context;
use vars qw(@ISA);
@ISA = qw(dpl::Web::Processor::Access);

#sub sessionTableName { 'user'; }
#sub userTableName { 'user'; }

sub addPath {
  my $self = shift;
  my $path = context('path') || [];
  foreach (@_) {
    push @$path,$_=~/^\// ? $_ : "/$_";
  }

  setContext('path',$path);
}


1;
