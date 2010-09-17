package dpl::Web::Apache;
use strict;
#use CGI;
use Exporter;
use dpl::Context;
use Apache2::RequestRec;
use base qw(Exporter);

use vars qw(
	    @EXPORT
	   );

@EXPORT = qw(param);

sub _fake_param {
  #$r->content" and "$r->args
  my $r = context('apr');
  my @a = $r->args();
  die join(',',@a);
  #  return scalar $r->param(@_);
  #  if (@_) {
  #    my $key = shift;
  #    return $r->param($key);
    #context('params')->{$key}=$r->param($key);
  #  } else {
  #    return scalar $r->param(@_);
  #}
}


1;
