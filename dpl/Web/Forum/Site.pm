package dpl::Web::Forum::Site;
use strict;
use YAML;
use URI::Escape;
use dpl::Db::Database;
use dpl::Web::Site;
use dpl::System;
use dpl::Context;
use Error qw(:try);
use Scalar::Util 'blessed';
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Web::Site);


sub show {
  my ($self, $result) = @_;
  my %output = (result=>$result,
                set=>getSettings(),
                context=>getContext(),
                site=>$self->data()
               );
  startTimer('show');
  my $view;
  my $template = $self->{object} ? $self->{object}->GetTemplate() : undef;
  $template = $self->{page}->{template} unless $template;
  if ($self->{processor}) {
    $output{data}    = $self->{processor}->data();
    $output{set_cookie} = $self->{processor}->getCookies();
    $output{options} = $self->{processor}->viewOptions();
    #    $output{params} = $self->{processor}->param();
    $view = $self->loadView($self->{template} || $self->{processor}->template() || $template);
  } else {
    $view = $self->loadView($template);
  }
  my $res =  $view->show(\%output,$self->{processor}->template_file());
#  $self->SaveOutput(\%output,$view->{file});
  stopTimer('show');
  return $res;
}

sub execute {
  my $self = shift;
  startTimer('execute');
  return try {
#    print STDERR "Execute\n";
    my $res = $self->SUPER::execute(@_);
    stopTimer('execute');
    return $res;
  } catch Error with {
 #   print STDERR "Error\n";
    stopTimer('execute');
    return $self->showError(shift->stringify);
  } otherwise {
#    print STDERR "Otherwise\n";
    stopTimer('execute');
    return $self->showError("Неизвестная ошибка системы: $@");
  };
}

sub showError {
  my ($self,$str) = @_;
  $self->{template}='error';
  $self->{processor}->{template_file}=undef;
  return $str;
}


sub SaveOutput {
  my ($self,$output,$template) = @_;
  #  die $self->{path};
  return undef unless $self->{query}=~/savedata$/;
  $self->{query}=~s/savedata$//;
  my $query = $self->{query} ? uri_escape("?$self->{query}") : '';
  my %o = %$output;
  delete $o{options};
  delete @o{qw(options dbs filters handler loggers)};
  $o{template} = $template;
  my $dir = '/home/danil/projects/tt/data/';
  #  my $path = uri_escape($self->{path}) || 'index.html';
  my $path = $self->{path} || 'index.html';
  $path  = $path.'index.html' if $path=~/\/$/;
  print STDERR "SaveOutput: $path?$self->{query}, $template ($dir$path$query)\n";
  open(FILE,"> $dir$path$query");
  my $res = unblessCode(\%o);
  print FILE Dump($res);
  close(FILE);
}

sub unblessCode {
  my $data = shift;

  if (UNIVERSAL::isa( $data, 'HASH' )) {
    my %h;
    foreach my $k (keys %$data) {
      $h{$k}=unblessCode($data->{$k});
    }
    return \%h;
  } elsif (UNIVERSAL::isa( $data, 'ARRAY' )) {
    my @a;
    foreach my $d (@$data) {
      push @a,unblessCode($d);
    }
    return \@a;
  } elsif (UNIVERSAL::isa( $data, 'SCALAR' )) {
    return ${$data};
} else {
  return $data;
}
}



1;
