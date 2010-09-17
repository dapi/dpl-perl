package dpl::Web::View::TT2;
use strict;
use Template;
use Apache2::RequestRec;
use Apache2::Const;
use HTTP::Date;
use dpl::Error;
use dpl::XML;
use dpl::Log;
use dpl::Web::View;
use dpl::Context;
use vars qw(@ISA);
@ISA = qw(dpl::Web::View);

sub process {
  my ($self,$data) = @_;
  my $code = $self->getAttribute('code',$data,Apache2::Const::DONE);
  $self->{file} = $self->getOption('file',$data);
  $self->{dir} = directory('template',1) || $self->getAttribute('dir',$data);
#  $self->{header} = $self->getOptions('header',$data);
  $self->{options} = $self->getOptions('options',$data);
  #  die $self->{dir};
  my @dir=($self->{dir});
  if (exists $self->{options}->{INCLUDE_PATH}) {
    push @dir, $self->{options}->{INCLUDE_PATH};
    delete $self->{options}->{INCLUDE_PATH};
  }
  my $r;
  $data->{objects}=$data->{context}->{objects}
    if $data->{context} && $data->{context}->{objects};
  my $tt = Template->
    new(%{$self->{options}},
	INCLUDE_PATH=>\@dir,
	OUTPUT=>\$r)
      || dpl::Error::fatal('Error init template',Template->error());
  $tt->process("$self->{file}",$data) || dpl::Error::fatal('Error process template',$tt->error());
  return $r;
}


sub show {
  my ($self,$data,$file) = @_;
  my $code = $self->getAttribute('code',$data,Apache2::Const::DONE);
  $self->{file} = $file || $self->{file} || $self->getOption('file',$data);
  $self->{dir} = directory('template',1) || $self->getAttribute('dir',$data);
  $self->{maxage} = $self->getAttribute('maxage',$data);
  $self->{expires} = $self->getAttribute('expires',$data);
  $self->{nocache} = $self->getAttribute('nocache',$data);
  $self->{header} = $self->getOptions('header',$data);
  $self->{options} = $self->getOptions('options',$data);
  $self->{set_cookie} = $data->{set_cookie};
  $self->{viewoptions} = $data->{options} || {};
  my $r = context('apr');
  if ($code == Apache2::Const::OK || $code == Apache2::Const::DECLINED || $code == Apache2::Const::DONE) {
    if ($r->prev || $r->header_only) {
      $self->sendHeader($data,$code);
    } else {
      $self->sendPage($data,$code);
    }
  } else {
    $self->{err_header}=$self->{header};
    $self->setErrPage($data,$code);
  }
#  logger->debug("View result code is: $code");
  return $code;
}

sub sendHeader {
  my ($self,$data,$code) = @_;
  my $r = context('apr');
  foreach (keys %{$self->{header}}) {
    if ($_ eq 'Content-Type') {
      $r->content_type($self->{header}->{$_});
    } else {
      $r->headers_out->set($_,$self->{header}->{$_});
    }
  }
  # устанавливается выше
  if (defined $self->{set_cookie}) {
    if (ref($self->{set_cookie})=~/array/i) {
      foreach (@{$self->{set_cookie}}) {
        $r->headers_out->set('Set-Cookie', $_);
      }
    } else {
      $r->headers_out->set('Set-Cookie', $self->{set_cookie});
    }
  }

  if (defined $self->{maxage}) {
    #print STDERR "Cache-control: max-age=$self->{maxage}\n";
    $r->headers_out->set('Cache-Control', "max-age=$self->{maxage}");
  } elsif (defined $self->{expires}) {
    my $e = HTTP::Date::time2str(time() + $self->{expires});
    $r->headers_out->set('Cache-Control', $e);
#    print STEDRR "Cache-control: $r\n";
  } elsif ($self->{nocache}) {
#    print STEDRR "Cache-control: no-cache\n";
    $r->no_cache(1);
    $r->headers_out->set('Cache-Control', "no-cache")
  } else {
#    print STEDRR "Cache-control: none\n";
    #    $r->set_etag;
  }
  #$r->rflush;
}


sub sendPage {
  my ($self,$data) = @_;
  my $r = context('apr');
  #  die $self->{dir};
  my @dir=($self->{dir});
  if (exists $self->{options}->{INCLUDE_PATH}) {
    push @dir, $self->{options}->{INCLUDE_PATH};
    delete $self->{options}->{INCLUDE_PATH};
  }
  $data->{objects}=$data->{context}->{objects}
    if $data->{context} && $data->{context}->{objects};

  my $tt = Template->
    new(%{$self->{options}},
	INCLUDE_PATH=>\@dir,
	OUTPUT=>$r,
        %{$self->{viewoptions}}) || dpl::Error::fatal('Error init template',Template->error());
  $self->sendHeader($data);
  return $tt->process("$self->{file}",$data)
    || dpl::Error::fatal('Error process template',$tt->error());
}


sub setErrPage {
  my ($self,$data,$code) = @_;
  my $r = context('apr');
#  $r->status($code);
  #  die "$r";
#  print STDERR "Code: $code\n";
  my $output;
  my $tt = Template->
    new(%{$self->{options}},
	INCLUDE_PATH=>$self->{dir},
        OUTPUT=>$r,
#	OUTPUT=>\$output
       ) || dpl::Error::fatal('Error init template',Template->error());

  foreach (keys %{$self->{err_header}}) {
    if ($_ eq 'Content-Type') {
      $r->content_type($self->{err_header}->{$_});
    } else {
      $r->headers_out->set($_,$self->{err_header}->{$_});
    }
  }


  $tt->process("$self->{file}",
	       $data)
    || dpl::Error::fatal('Error process template',$tt->error());
  $r->status($code);
}



1;
