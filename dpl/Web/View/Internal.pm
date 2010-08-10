package dpl::Web::View::Internal;
use strict;
use Apache2::Const;
use URI::Escape;
use dpl::Error;
use dpl::XML;
use dpl::Log;
use dpl::Context;
use dpl::XML;
use dpl::Web::View;
use vars qw(@ISA);
@ISA = qw(dpl::Web::View);

sub show {
  my ($self,$data) = @_;
  my $code = $self->getAttribute('code',$data);
  if ($code eq 'NOT_FOUND') {
    return Apache2::Const::NOT_FOUND;
  } elsif ($code eq 'DECLINE') {
    return Apache2::Const::DECLINED;
  } elsif ($code eq 'OK') {
    return Apache2::Const::OK;
  } elsif ($code eq '_FILE_') {
    return $self->SendFile($data);
  } elsif ($code eq '_DATA_') {
    return $self->SendData($data);
  } elsif ($code eq 'REDIRECT') {
    my $r = context('apr');
    if (defined $data->{set_cookie}) {
      if (ref($data->{set_cookie})=~/array/i) {
        foreach (@{$data->{set_cookie}}) {
          $r->err_headers_out->set('Set-Cookie', $_);
        }
      } else {
        $r->err_headers_out->set('Set-Cookie', $data->{set_cookie});
      }
    }
    $r->no_cache(1) if $self->getAttribute('nocache',$data);
    my $url = $self->Interpolate(xmlText($self->{tnode}),$data);
    $r->headers_out->set(Location=>$url);
    #$r->err_headers_out->set('Pragma','no-cache');
    #    $r->err_headers_out->set('Transfer-Encoding','chunked');
    return Apache2::Const::REDIRECT;
  } else {
    dpl::Error::fatal("Unknown internal view code: '$code'");
  }
}

sub SendFile {
  my ($self,$data) = @_;
  my $file = $data->{result};
  my $filename = $self->getOption('filename',$data,1);
  my $maxage = $self->getAttribute('maxage',$data);
  my $nocache = $self->getAttribute('nocache',$data);
  my $header = $self->getOptions('header',$data);

  my $r = context('apr');
  my @s = stat $file;
  $r->filename($file);
  $r->update_mtime($s[9]);
  $r->headers_out->set("Content-Length",$s[7]);
  $r->set_etag;
  $r->set_content_length($s[7]);
  foreach (keys %$header) {
    if ($_ eq 'Content-Type') {
      $r->content_type($header->{$_});
    } else {
      $r->headers_out->set($_,$header->{$_});
    }
  }
  #  Content-Type: text/plain; charset=koi8-r
  # set last modified
  if ($nocache) {
    $r->no_cache(1);
    $r->headers_out->set('Cache-control', "no-cache")
  } elsif (defined $maxage) {
    $r->headers_out->set('Cache-control', "max-age=$maxage");
  }
  $r->rflush;

  open(FILE,$file);
  while (<FILE>) {
    $r->print($_);
  }
  close(FILE);
  return Apache2::Const::OK;
}

sub SendData {
  my ($self,$data) = @_;
  my $filename = $self->getOption('filename',$data,1);
  my $maxage = $self->getAttribute('maxage',$data);
  my $nocache = $self->getAttribute('nocache',$data);
  my $header = $self->getOptions('header',$data);

  my $r = context('apr');
  $r->headers_out->set("Content-Length",length($data->{result}->{data}));
  foreach (keys %$header) {
    if ($_ eq 'Content-Type') {
      $r->content_type($header->{$_});
    } else {
      $r->headers_out->set($_,$header->{$_});
    }
  }
  #  Content-Type: text/plain; charset=koi8-r
  # set last modified
  if ($nocache) {
    $r->no_cache(1);
    $r->headers_out->set('Cache-control', "no-cache")
  } elsif (defined $maxage) {
    $r->headers_out->set('Cache-control', "max-age=$maxage");
  }
  $r->rflush;

  $r->print($data->{result}->{data});
  return Apache2::Const::OK;

}


1;
